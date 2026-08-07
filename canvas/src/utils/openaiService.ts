import { ExperimentJSON, AnalysisResult } from '../types';

const OPENAI_BASE_URL = 'https://api.openai.com/v1';
const OPENAI_API_KEY = import.meta.env.VITE_OPENAI_API_KEY || '';

// Model tiers picked per task, not one-size-fits-all:
// - Luna: cheap + fast, used for short conversational hints
// - Terra: balanced, used for code generation
// - Sol: frontier reasoning, used for structured experiment analysis
const MODEL_FAST = 'gpt-5.6-luna';
const MODEL_BALANCED = 'gpt-5.6-terra';
const MODEL_REASONING = 'gpt-5.6-sol';

type ReasoningEffort = 'none' | 'low' | 'medium' | 'high' | 'xhigh';

interface JsonSchemaFormat {
  name: string;
  schema: Record<string, unknown>;
}

const ANALYSIS_RESULT_SCHEMA: Record<string, unknown> = {
  type: 'object',
  properties: {
    success: { type: 'boolean' },
    title: { type: 'string' },
    message: { type: 'string' },
    mistake: { type: ['string', 'null'] },
    explanation: { type: 'string' },
    svg: { type: ['string', 'null'] },
  },
  required: ['success', 'title', 'message', 'mistake', 'explanation', 'svg'],
  additionalProperties: false,
};

async function callOpenAI(
  model: string,
  effort: ReasoningEffort,
  input: string,
  jsonSchema?: JsonSchemaFormat
): Promise<string> {
  const body: Record<string, unknown> = {
    model,
    reasoning: { effort },
    input: [{ role: 'user', content: input }],
  };

  if (jsonSchema) {
    body.text = {
      format: {
        type: 'json_schema',
        name: jsonSchema.name,
        strict: true,
        schema: jsonSchema.schema,
      },
    };
  }

  const response = await fetch(`${OPENAI_BASE_URL}/responses`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`OpenAI API error (${response.status}): ${errorText}`);
  }

  const data = await response.json();

  if (typeof data.output_text === 'string' && data.output_text.length > 0) {
    return data.output_text;
  }

  const message = data.output?.find((item: any) => item.type === 'message');
  const textPart = message?.content?.find((part: any) => part.type === 'output_text');
  if (textPart?.text) {
    return textPart.text;
  }

  throw new Error('OpenAI API returned no output text');
}

export class OpenAIService {
  // setApiKey is kept for backward compatibility but is no longer needed
  setApiKey(_apiKey: string) {
    // No-op: the API key is sourced from VITE_OPENAI_API_KEY
  }

  async getHint(experimentJSON: ExperimentJSON, userQuestion: string): Promise<string> {
    const nodeCount = experimentJSON.nodes.length;
    const edgeCount = experimentJSON.edges.length;
    const categories = [...new Set(experimentJSON.nodes.map(n => n.data.component.category))];
    const componentLabels = experimentJSON.nodes.map(n => n.data.label).join(', ');

    const prompt = `
You are a friendly lab assistant robot 🤖 helping a student with their experiment.

CURRENT EXPERIMENT CONTEXT:
- Total Components: ${nodeCount}
- Total Connections: ${edgeCount}
- Categories Used: ${categories.join(', ')}
- Components on Canvas: ${componentLabels}

DETAILED EXPERIMENT STRUCTURE:
${JSON.stringify(experimentJSON, null, 2)}

STUDENT'S QUESTION: "${userQuestion}"

INSTRUCTIONS:
Analyze the current experiment setup and the student's question. Provide a helpful hint to guide them in the right direction.

DO NOT:
- Give the direct solution or complete answer
- Tell them exactly what to add or how to fix it
- Provide step-by-step instructions

DO:
- Ask guiding questions about their current components
- Point out relationships they might have missed
- Suggest what to think about regarding specific components they already have
- Encourage exploration of connections between existing components
- Reference specific components they've added by name
- Help them think critically about what's missing or incorrect

Keep your response conversational, encouraging, friendly, and under 120 words. Use emojis occasionally! 🔬✨
`;

    try {
      return await callOpenAI(MODEL_FAST, 'low', prompt);
    } catch (error) {
      throw new Error(`Failed to get hint: ${error}`);
    }
  }

  async analyzeExperiment(experimentJSON: ExperimentJSON): Promise<AnalysisResult> {
    const prompt = `
You are an expert science and engineering simulation AI. Analyze the following experiment setup and predict the outcome.

The experiment is represented as a node-based graph where:
- Each node represents a component (electronic, chemical, physical, or code block)
- Edges represent connections and flow between components
- Conditions on edges determine when connections are active

Experiment JSON:
${JSON.stringify(experimentJSON, null, 2)}

Analyze this experiment and determine:
- Whether it is valid and produces a result (success), or fails / is incomplete
- A short title: "Experiment Success!" or "Experiment Failed"
- A concise 1-2 sentence summary message
- If failed, a clear description of the mistake WITHOUT giving away the solution (null if success)
- A detailed explanation of what happened and why
- If success, a colorful, modern, self-contained SVG string (starting with <svg... and ending with </svg>) visualizing the output (a graph, chemical reaction, circuit diagram, or similar). Null if failed.
`;

    try {
      const text = await callOpenAI(MODEL_REASONING, 'high', prompt, {
        name: 'experiment_analysis',
        schema: ANALYSIS_RESULT_SCHEMA,
      });

      return JSON.parse(text) as AnalysisResult;
    } catch (error) {
      console.error('OpenAI Analysis Error:', error);
      return {
        success: false,
        title: 'Analysis Error',
        message: 'Failed to analyze the experiment.',
        mistake: 'There was an error communicating with the AI service.',
        explanation: `Error details: ${error}`,
      };
    }
  }

  async generateVisualization(experimentJSON: ExperimentJSON): Promise<string> {
    const prompt = `
Based on this experiment setup, generate Python code using matplotlib or similar libraries to visualize the expected output.

Experiment JSON:
${JSON.stringify(experimentJSON, null, 2)}

Generate complete, runnable Python code that creates a visualization of the experiment results.
Only return the code, no explanations.
`;

    try {
      return await callOpenAI(MODEL_BALANCED, 'medium', prompt);
    } catch (error) {
      throw new Error(`Failed to generate visualization: ${error}`);
    }
  }
}

export const openaiService = new OpenAIService();

export const getTheme = () => {
  if (typeof window !== 'undefined') {
    return document.documentElement.classList.contains('dark') ? 'dark' : 'light';
  }
  return 'light';
};

// Wrapper functions for App_Challenge.tsx
export const analyzeExperiment = async (
  nodes: any[],
  edges: any[]
): Promise<AnalysisResult> => {
  const experimentJSON: ExperimentJSON = {
    nodes: nodes.map(node => ({
      id: node.id,
      type: node.type,
      position: node.position,
      data: {
        label: node.data.label,
        component: {
          id: node.id,
          label: node.data.label,
          category: node.data.category || 'General',
          icon: '',
          description: '',
          inputs: 1,
          outputs: 1,
          properties: {}
        }
      }
    })),
    edges: edges.map(edge => ({
      id: edge.id,
      source: edge.source,
      target: edge.target,
      condition: edge.data?.condition
    })),
    metadata: {
      title: 'Challenge Experiment',
      description: 'User submitted challenge solution',
      created: new Date().toISOString()
    }
  };

  return openaiService.analyzeExperiment(experimentJSON);
};

export const getHint = async (
  userMessage: string,
  experimentContext: any
): Promise<string> => {
  const experimentJSON: ExperimentJSON = {
    nodes: experimentContext.nodes.map((node: any) => ({
      id: node.id,
      type: 'custom',
      position: { x: 0, y: 0 },
      data: {
        label: node.label,
        component: {
          id: node.id,
          label: node.label,
          category: node.category || 'General',
          icon: '',
          description: '',
          inputs: 1,
          outputs: 1,
          properties: {}
        }
      }
    })),
    edges: experimentContext.edges.map((edge: any) => ({
      id: `${edge.source}-${edge.target}`,
      source: edge.source,
      target: edge.target
    })),
    metadata: {
      title: 'Current Experiment',
      description: 'User experiment context for hint',
      created: new Date().toISOString()
    }
  };

  return openaiService.getHint(experimentJSON, userMessage);
};
