import { useState, useCallback, useRef, DragEvent, useEffect, useMemo } from 'react';
import ReactFlow, {
  Background,
  Controls,
  MiniMap,
  addEdge,
  Connection,
  Node,
  useNodesState,
  useEdgesState,
  NodeTypes,
  Edge,
} from 'reactflow';
import 'reactflow/dist/style.css';
import { X, CheckCircle, AlertCircle, Zap, FlaskConical, Atom, Code2, PartyPopper, XCircle, Target, Trophy } from 'lucide-react';
import { AnimatePresence, motion } from 'framer-motion';
import confetti from 'canvas-confetti';

import { Navbar } from './components/Navbar';
import { ComponentLibrary } from './components/ComponentLibrary';
import { CustomNode } from './components/CustomNode';
import { RightSidebar } from './components/RightSidebar';
import { DrawingCanvas } from './components/DrawingCanvas';
import { RobotAssistant } from './components/RobotAssistant';
import { PromptDialog, PromptDialogState } from './components/PromptDialog';
import { ToastStack } from './components/ToastStack';
import { ComponentData, AnalysisResult } from './types';
import { DrawingTool, DrawnShape } from './types/drawing';
import { generateExperimentJSON, downloadJSON } from './utils/jsonGenerator';
import { openaiService, buildExperimentImagePrompt } from './utils/openaiService';
import { EXAMPLE_EXPERIMENTS, EXAMPLE_LIST } from './data/exampleExperiments';
import { shapeRecognizer } from './utils/shapeRecognition';
import { CATEGORIES } from './data/componentLibrary';
import { useUndoRedo } from './hooks/useUndoRedo';
import { useTheme } from './hooks/useTheme';
import { useToasts } from './hooks/useToasts';

const nodeTypes: NodeTypes = {
  custom: CustomNode,
};

const MAIN_APP_ORIGIN = import.meta.env.VITE_MAIN_APP_ORIGIN || 'http://localhost:3000';

interface ActiveChallenge {
  source: 'voom' | 'challenge';
  roomId?: string;
  questionId?: string;
  questionIndex?: number;
  title: string;
  description?: string;
  difficulty?: string;
  category?: string;
  points?: number;
}

function App() {
  const [nodes, setNodes, onNodesChange] = useNodesState([]);
  const [edges, setEdges, onEdgesChange] = useEdgesState([]);
  const { takeSnapshot, undo, redo, canUndo, canRedo } = useUndoRedo();
  const { isDark, toggleTheme } = useTheme();
  const { toasts, showToast, dismissToast } = useToasts();
  const [promptState, setPromptState] = useState<PromptDialogState | null>(null);

  const showPrompt = useCallback((title: string, defaultValue: string, onConfirm: (value: string) => void) => {
    setPromptState({ title, defaultValue, onConfirm });
  }, []);

  const showConfirm = useCallback((title: string, message: string, onConfirm: () => void, danger = false) => {
    setPromptState({
      title,
      message,
      showInput: false,
      danger,
      confirmLabel: danger ? 'Delete' : 'Confirm',
      onConfirm: () => onConfirm(),
    });
  }, []);

  const [apiKey, setApiKey] = useState('');
  const [showApiKeyModal, setShowApiKeyModal] = useState(false);
  const [showWelcomeModal, setShowWelcomeModal] = useState(true);
  const [showExamplesModal, setShowExamplesModal] = useState(false);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [analysisResult, setAnalysisResult] = useState<AnalysisResult | null>(null);
  const [showResults, setShowResults] = useState(false);
  const [isRenderingImage, setIsRenderingImage] = useState(false);
  const [imageError, setImageError] = useState<string | null>(null);
  const reactFlowWrapper = useRef<HTMLDivElement>(null);
  const [reactFlowInstance, setReactFlowInstance] = useState<any>(null);
  const [currentDrawingTool, setCurrentDrawingTool] = useState<DrawingTool | null>(null);
  const [leftSidebarCollapsed, setLeftSidebarCollapsed] = useState(false);
  const [rightSidebarCollapsed, setRightSidebarCollapsed] = useState(false);
  const [selectedNodeId, setSelectedNodeId] = useState<string | null>(null);
  const [activeChallenge, setActiveChallenge] = useState<ActiveChallenge | null>(null);
  const [challengeSolved, setChallengeSolved] = useState(false);

  const selectedNode = useMemo(
    () => nodes.find((n) => n.id === selectedNodeId) || null,
    [nodes, selectedNodeId]
  );

  const categoryStats = useMemo(() => {
    const counts = new Map<string, number>();
    nodes.forEach((n) => {
      const category = n.data.component?.category;
      if (category) counts.set(category, (counts.get(category) || 0) + 1);
    });
    return CATEGORIES
      .filter((cat) => counts.has(cat.id))
      .map((cat) => ({ id: cat.icon, label: cat.label, count: counts.get(cat.id) || 0, color: cat.color }));
  }, [nodes]);

  // Check if user has visited before
  useEffect(() => {
    const hasVisited = localStorage.getItem('aiexp-visited');
    if (hasVisited) {
      setShowWelcomeModal(false);
    }
  }, []);

  const handleCloseWelcome = () => {
    localStorage.setItem('aiexp-visited', 'true');
    setShowWelcomeModal(false);
  };

  // Pick up a question handed off from the Voom room or Challenges flow
  useEffect(() => {
    const voomRaw = localStorage.getItem('currentVoomQuestion');
    if (voomRaw) {
      try {
        const q = JSON.parse(voomRaw);
        setActiveChallenge({
          source: 'voom',
          roomId: q.roomId,
          questionId: q.questionId,
          title: q.questionText,
          points: q.points,
        });
      } catch {
        // ignore malformed handoff data
      }
      localStorage.removeItem('currentVoomQuestion');
      return;
    }

    const challengeRaw = localStorage.getItem('currentChallengeQuestion');
    if (challengeRaw) {
      try {
        const q = JSON.parse(challengeRaw);
        setActiveChallenge({
          source: 'challenge',
          questionIndex: q.questionIndex,
          title: q.question,
          description: q.description,
          difficulty: q.difficulty,
          category: q.category,
        });
      } catch {
        // ignore malformed handoff data
      }
      localStorage.removeItem('currentChallengeQuestion');
    }
  }, []);

  const notifyChallengeSolved = useCallback(() => {
    if (!activeChallenge || challengeSolved) return;
    setChallengeSolved(true);
    if (window.opener) {
      window.opener.postMessage(
        {
          type: 'canvas-challenge-solved',
          source: activeChallenge.source,
          roomId: activeChallenge.roomId,
          questionId: activeChallenge.questionId,
          questionIndex: activeChallenge.questionIndex,
          points: activeChallenge.points,
        },
        MAIN_APP_ORIGIN
      );
    }
  }, [activeChallenge, challengeSolved]);

  const onConnect = useCallback(
    (params: Connection) => {
      takeSnapshot(nodes, edges);
      const newEdge = {
        ...params,
        type: 'smoothstep',
        animated: true,
        style: {
          stroke: '#3b82f6',
          strokeWidth: 2.5,
          strokeLinecap: 'round',
        },
      };
      setEdges((eds) => addEdge(newEdge, eds));
    },
    [setEdges, takeSnapshot, nodes, edges]
  );

  const onEdgeClick = useCallback(
    (_event: React.MouseEvent, edge: Edge) => {
      showPrompt(
        'Label this connection',
        (edge.label as string) || '',
        (label) => {
          takeSnapshot(nodes, edges);
          setEdges((eds) =>
            eds.map((e) => (e.id === edge.id ? { ...e, label } : e))
          );
        }
      );
    },
    [setEdges, takeSnapshot, nodes, edges, showPrompt]
  );

  const onNodeDragStart = useCallback(() => {
    takeSnapshot(nodes, edges);
  }, [takeSnapshot, nodes, edges]);

  const onNodeClick = useCallback((_event: React.MouseEvent, node: Node) => {
    setSelectedNodeId(node.id);
  }, []);

  const onPaneClick = useCallback(() => {
    setSelectedNodeId(null);
  }, []);

  useEffect(() => {
    if (selectedNodeId && !nodes.some((n) => n.id === selectedNodeId)) {
      setSelectedNodeId(null);
    }
  }, [nodes, selectedNodeId]);

  const updateNodeLabel = useCallback((nodeId: string, label: string) => {
    setNodes((nds) => nds.map((n) => (n.id === nodeId ? { ...n, data: { ...n.data, customText: label } } : n)));
  }, [setNodes]);

  const updateNodeProperty = useCallback((nodeId: string, key: string, value: any) => {
    setNodes((nds) => nds.map((n) => {
      if (n.id !== nodeId) return n;
      return {
        ...n,
        data: {
          ...n.data,
          component: {
            ...n.data.component,
            properties: { ...n.data.component.properties, [key]: value },
          },
        },
      };
    }));
  }, [setNodes]);

  const deleteNode = useCallback((nodeId: string) => {
    takeSnapshot(nodes, edges);
    setNodes((nds) => nds.filter((n) => n.id !== nodeId));
    setEdges((eds) => eds.filter((e) => e.source !== nodeId && e.target !== nodeId));
    setSelectedNodeId(null);
  }, [nodes, edges, takeSnapshot, setNodes, setEdges]);

  const onDragOver = useCallback((event: DragEvent) => {
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';
  }, []);

  const onDrop = useCallback(
    (event: DragEvent) => {
      event.preventDefault();

      if (!reactFlowWrapper.current || !reactFlowInstance) return;

      const componentData = event.dataTransfer.getData('application/reactflow');
      if (!componentData) return;

      const component: ComponentData = JSON.parse(componentData);
      const bounds = reactFlowWrapper.current.getBoundingClientRect();
      const position = reactFlowInstance.screenToFlowPosition({
        x: event.clientX - bounds.left,
        y: event.clientY - bounds.top,
      });

      const newNode: Node = {
        id: `${component.id}_${Date.now()}`,
        type: 'custom',
        position,
        data: {
          label: component.label,
          component,
        },
      };

      takeSnapshot(nodes, edges);
      setNodes((nds) => nds.concat(newNode));
    },
    [reactFlowInstance, setNodes, takeSnapshot, nodes, edges]
  );

  const handleRunExperiment = async () => {

    if (nodes.length === 0) {
      showToast('Please add components to your experiment first!', 'error');
      return;
    }

    setIsAnalyzing(true);
    setShowResults(true);
    setAnalysisResult(null);
    setIsRenderingImage(false);
    setImageError(null);

    try {
      const experimentJSON = generateExperimentJSON(nodes, edges);

      // Both requests go out together. The illustration is prompted from the
      // graph itself, so it does not wait on the verdict - total time is the
      // slower of the two, not the sum. The .catch is attached immediately so
      // this promise can sit in flight without an unhandled rejection.
      setIsRenderingImage(true);
      const imagePromise = openaiService
        .generateImage(buildExperimentImagePrompt(experimentJSON))
        .then((url) => ({ url, error: null as string | null }))
        .catch(() => ({ url: null, error: 'The illustration could not be rendered.' }));

      const result = await openaiService.analyzeExperiment(experimentJSON);
      // Show the verdict the moment it lands, picture still rendering.
      setAnalysisResult(result);

      if (result.success) {
        confetti({
          particleCount: 150,
          spread: 70,
          origin: { y: 0.6 },
          colors: ['#10b981', '#3b82f6', '#f59e0b', '#ec4899']
        });
        notifyChallengeSolved();
      }

      const image = await imagePromise;
      setIsRenderingImage(false);
      if (image.url) {
        setAnalysisResult((prev) => (prev === result ? { ...prev, imageUrl: image.url! } : prev));
      } else {
        setImageError(image.error);
      }
    } catch (error: any) {
      setAnalysisResult({
        success: false,
        title: "System Error",
        message: error.message || "An unexpected error occurred",
        mistake: "Failed to communicate with AI service",
        explanation: "Please check your API key and internet connection."
      });
    } finally {
      setIsAnalyzing(false);
      setIsRenderingImage(false);
    }
  };

  const handleDownloadJSON = () => {
    if (nodes.length === 0) {
      showToast('Please add components to your experiment first!', 'error');
      return;
    }
    const experimentJSON = generateExperimentJSON(nodes, edges);
    downloadJSON(experimentJSON);
  };

  const handleClearCanvas = () => {
    if (nodes.length === 0) return;
    showConfirm(
      'Clear the canvas?',
      'This removes every component and connection you\'ve added. This can\'t be undone.',
      () => {
        takeSnapshot(nodes, edges);
        setNodes([]);
        setEdges([]);
        setAnalysisResult(null);
        setShowResults(false);
      },
      true
    );
  };

  const handleLoadExample = (exampleId: string) => {
    const example = EXAMPLE_EXPERIMENTS[exampleId];
    if (example) {
      takeSnapshot(nodes, edges);
      setNodes(example.nodes as Node[]);
      setEdges(example.edges as Edge[]);
      setShowExamplesModal(false);
      setAnalysisResult(null);
      setShowResults(false);
    }
  };

  const handleShapeComplete = useCallback((shape: DrawnShape) => {
    const newNode = shapeRecognizer.convertShapeToNode(shape, shape.label);
    takeSnapshot(nodes, edges);
    setNodes((nds) => nds.concat(newNode as Node));
    setCurrentDrawingTool(null);
  }, [setNodes, takeSnapshot, nodes, edges]);

  const handleToolSelect = useCallback((tool: DrawingTool | null) => {
    if (!tool) {
      setCurrentDrawingTool(null);
      return;
    }

    if (tool === 'freehand') {
      // Only freehand requires drawing on the canvas.
      // Clicking it again while active toggles draw mode back off.
      setCurrentDrawingTool((current) => (current === 'freehand' ? null : tool));
      return;
    }

    // Get canvas center position
    const canvasCenter = {
      x: window.innerWidth / 2,
      y: window.innerHeight / 2,
    };

    // Create shape directly at center
    const size = 100;
    let points: any[] = [];
    let bounds = { x: canvasCenter.x - size / 2, y: canvasCenter.y - size / 2, width: size, height: size };

    switch (tool) {
      case 'rectangle':
        points = [
          { x: bounds.x, y: bounds.y },
          { x: bounds.x + size, y: bounds.y },
          { x: bounds.x + size, y: bounds.y + size },
          { x: bounds.x, y: bounds.y + size },
          { x: bounds.x, y: bounds.y },
        ];
        break;
      case 'circle':
        points = [];
        for (let i = 0; i <= 32; i++) {
          const angle = (i / 32) * 2 * Math.PI;
          points.push({
            x: canvasCenter.x + (size / 2) * Math.cos(angle),
            y: canvasCenter.y + (size / 2) * Math.sin(angle),
          });
        }
        break;
      case 'triangle':
        points = [
          { x: canvasCenter.x, y: bounds.y },
          { x: bounds.x + size, y: bounds.y + size },
          { x: bounds.x, y: bounds.y + size },
          { x: canvasCenter.x, y: bounds.y },
        ];
        break;
      case 'line':
        points = [
          { x: bounds.x, y: canvasCenter.y },
          { x: bounds.x + size, y: canvasCenter.y },
        ];
        break;
      case 'arrow':
        points = [
          { x: bounds.x, y: canvasCenter.y },
          { x: bounds.x + size, y: canvasCenter.y },
        ];
        break;
    }

    showPrompt(`Label this ${tool}`, tool.charAt(0).toUpperCase() + tool.slice(1), (label) => {
      if (!label.trim()) return;

      const shape: DrawnShape = {
        id: `shape_${Date.now()}`,
        type: tool as any,
        points,
        bounds,
        label: label.trim(),
        recognized: true,
      };

      const newNode = shapeRecognizer.convertShapeToNode(shape, shape.label);
      takeSnapshot(nodes, edges);
      setNodes((nds) => nds.concat(newNode as Node));
    });
  }, [setNodes, takeSnapshot, nodes, edges, showPrompt]);

  const handleImportJSON = () => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.json';
    input.onchange = (e: any) => {
      const file = e.target.files[0];
      if (file) {
        const reader = new FileReader();
        reader.onload = (event) => {
          try {
            const json = JSON.parse(event.target?.result as string);
            if (json.nodes && json.edges) {
              takeSnapshot(nodes, edges);
              setNodes(json.nodes);
              setEdges(json.edges);
              showToast('Experiment loaded successfully!', 'success');
            } else {
              showToast('Invalid experiment file format!', 'error');
            }
          } catch (error) {
            showToast('Error reading file. Please make sure it\'s a valid JSON file.', 'error');
          }
        };
        reader.readAsText(file);
      }
    };
    input.click();
  };

  const handleRequestHint = async (userMessage: string): Promise<string> => {
    try {
      const experimentJSON = generateExperimentJSON(nodes, edges);
      const hint = await openaiService.getHint(experimentJSON, userMessage);
      return hint;
    } catch (error: any) {
      return "Sorry, I'm having trouble thinking right now. Can you try asking again?";
    }
  };

  return (
    <div className="flex flex-col w-screen h-screen font-sans bg-white dark:bg-zinc-950 text-zinc-900 dark:text-zinc-100 transition-colors duration-300">
      <Navbar
        isAnalyzing={isAnalyzing}
        canUndo={canUndo}
        canRedo={canRedo}
        isDark={isDark}
        nodeCount={nodes.length}
        edgeCount={edges.length}
        onUndo={() => undo(nodes, edges, setNodes, setEdges)}
        onRedo={() => redo(nodes, edges, setNodes, setEdges)}
        onRunExperiment={handleRunExperiment}
        onShowExamples={() => setShowExamplesModal(true)}
        onToggleTheme={toggleTheme}
        onDownloadJSON={handleDownloadJSON}
        onImportJSON={handleImportJSON}
        onClearCanvas={handleClearCanvas}
      />

      {activeChallenge && (
        <div
          className={`flex items-center gap-3 px-6 py-3 border-b text-sm ${
            challengeSolved
              ? 'bg-emerald-50 dark:bg-emerald-500/10 border-emerald-200 dark:border-emerald-500/20'
              : 'bg-orange-50 dark:bg-orange-500/10 border-orange-200 dark:border-orange-500/20'
          }`}
        >
          {challengeSolved ? (
            <CheckCircle size={18} className="text-emerald-500 flex-shrink-0" />
          ) : (
            <Target size={18} className="text-orange-500 flex-shrink-0" />
          )}
          <div className="flex-1 min-w-0">
            <div className="font-semibold text-zinc-900 dark:text-zinc-100 truncate">
              {activeChallenge.title}
            </div>
            {activeChallenge.description && (
              <div className="text-xs text-zinc-500 dark:text-zinc-400 truncate">
                {activeChallenge.description}
              </div>
            )}
          </div>
          {activeChallenge.difficulty && (
            <span className="px-2.5 py-1 rounded-lg text-xs font-semibold uppercase bg-white/70 dark:bg-white/10 text-zinc-600 dark:text-zinc-300 flex-shrink-0">
              {activeChallenge.difficulty}
            </span>
          )}
          {typeof activeChallenge.points === 'number' && (
            <span className="flex items-center gap-1 px-2.5 py-1 rounded-lg text-xs font-bold bg-white/70 dark:bg-white/10 text-orange-600 dark:text-orange-400 flex-shrink-0">
              <Trophy size={12} />
              {activeChallenge.points} pts
            </span>
          )}
          <span className="text-xs font-medium flex-shrink-0 text-zinc-500 dark:text-zinc-400">
            {challengeSolved ? 'Solved! You can return to the other tab.' : 'Run Experiment to submit'}
          </span>
        </div>
      )}

      <div className="flex flex-1 min-h-0">
        {/* Component Library Sidebar */}
        <ComponentLibrary
          onDragStart={() => { }}
          collapsed={leftSidebarCollapsed}
          onToggleCollapse={() => setLeftSidebarCollapsed((v) => !v)}
        />

        {/* Main Canvas */}
        <div ref={reactFlowWrapper} className="flex-1 relative">
          <DrawingCanvas
            currentTool={currentDrawingTool}
            onShapeComplete={handleShapeComplete}
            onRequestLabel={showPrompt}
            onUnrecognizedShape={() => showToast('Shape not recognized. Try drawing more clearly: rectangle, circle, triangle, or line.', 'error')}
            onCancel={() => setCurrentDrawingTool(null)}
          />

          <ReactFlow
            nodes={nodes}
            edges={edges}
            onNodesChange={onNodesChange}
            onEdgesChange={onEdgesChange}
            onConnect={onConnect}
            onEdgeClick={onEdgeClick}
            onNodeClick={onNodeClick}
            onPaneClick={onPaneClick}
            onInit={setReactFlowInstance}
            onDrop={onDrop}
            onDragOver={onDragOver}
            onNodeDragStart={onNodeDragStart}
            nodeTypes={nodeTypes}
            fitView
            deleteKeyCode="Delete"
          >
            <Background
              color={isDark ? '#27272a' : '#e4e4e7'}
              gap={22}
              size={1}
              style={{ backgroundColor: isDark ? '#09090b' : '#ffffff' }}
            />
            <Controls />
            <MiniMap
              style={{ backgroundColor: isDark ? '#18181b' : '#f4f4f5' }}
              maskColor={isDark ? 'rgba(9, 9, 11, 0.7)' : 'rgba(244, 244, 245, 0.7)'}
              nodeColor={isDark ? '#3f3f46' : '#d4d4d8'}
            />
          </ReactFlow>
        </div>

        {/* Tools + Inspector Sidebar */}
        <RightSidebar
          collapsed={rightSidebarCollapsed}
          onToggleCollapse={() => setRightSidebarCollapsed((v) => !v)}
          selectedTool={currentDrawingTool}
          onToolSelect={handleToolSelect}
          selectedNode={selectedNode}
          onUpdateLabel={updateNodeLabel}
          onUpdateProperty={updateNodeProperty}
          onDeleteNode={deleteNode}
          nodeCount={nodes.length}
          edgeCount={edges.length}
          categoryStats={categoryStats}
        />
      </div>

      {/* Results Modal */}
      <AnimatePresence>
        {showResults && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center z-[2000]"
          >
            <motion.div
              initial={{ opacity: 0, y: 20, scale: 0.97 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: 20, scale: 0.97 }}
              transition={{ duration: 0.2 }}
              className="bg-white dark:bg-zinc-950 border border-zinc-200 dark:border-white/10 w-[90%] h-[90%] rounded-3xl shadow-[0_20px_60px_rgba(0,0,0,0.25)] dark:shadow-[0_20px_60px_rgba(0,0,0,0.7)] flex flex-col overflow-hidden relative"
            >
              {/* Header */}
              <div
                className={`px-8 py-5 border-b border-zinc-200 dark:border-white/10 flex justify-between items-center ${
                  analysisResult?.success ? 'bg-emerald-50 dark:bg-emerald-500/10' : analysisResult ? 'bg-red-50 dark:bg-red-500/10' : 'bg-zinc-50 dark:bg-zinc-900'
                }`}
              >
                <div className="flex items-center gap-3.5">
                  {analysisResult ? (
                    analysisResult.success ? (
                      <CheckCircle size={30} className="text-emerald-500" />
                    ) : (
                      <AlertCircle size={30} className="text-red-500" />
                    )
                  ) : (
                    <div className="w-6 h-6 border-[3px] border-zinc-200 dark:border-white/10 border-t-orange-500 rounded-full animate-spin" />
                  )}
                  <div>
                    <h2 className="font-serif text-2xl text-zinc-900 dark:text-white m-0">
                      {analysisResult ? analysisResult.title : 'Analyzing Experiment...'}
                    </h2>
                    {analysisResult && (
                      <p className="mt-1 text-sm text-zinc-500 dark:text-zinc-400">
                        {analysisResult.message}
                      </p>
                    )}
                  </div>
                </div>
                <button
                  onClick={() => setShowResults(false)}
                  className="w-10 h-10 rounded-full bg-zinc-100 dark:bg-white/5 border border-zinc-200 dark:border-white/10 flex items-center justify-center text-zinc-500 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-white hover:bg-zinc-200 dark:hover:bg-white/10 transition-colors"
                >
                  <X size={20} />
                </button>
              </div>

              {/* Content */}
              <div className="flex-1 overflow-y-auto p-8 flex gap-8 bg-white dark:bg-zinc-950">
                {analysisResult ? (
                  <>
                    {/* Left Column: Explanation / Mistake */}
                    <div className="flex-1 flex flex-col gap-5">
                      {analysisResult.success ? (
                        <div className="bg-zinc-50 dark:bg-zinc-900 p-6 rounded-2xl border border-zinc-200 dark:border-white/10">
                          <h3 className="mt-0 text-lg font-semibold text-emerald-600 dark:text-emerald-500 flex items-center gap-2">
                            <PartyPopper size={19} />
                            Congratulations!
                          </h3>
                          <div className="text-[15px] leading-relaxed text-zinc-600 dark:text-zinc-300 whitespace-pre-wrap">
                            {analysisResult.explanation}
                          </div>
                        </div>
                      ) : (
                        <div className="bg-red-50 dark:bg-red-500/10 p-6 rounded-2xl border border-red-200 dark:border-red-500/20">
                          <h3 className="mt-0 text-lg font-semibold text-red-600 dark:text-red-400 flex items-center gap-2">
                            <XCircle size={19} />
                            Experiment Failed
                          </h3>
                          <div className="text-[15px] leading-relaxed text-red-800/90 dark:text-red-200/90">
                            <strong>Mistake:</strong> {analysisResult.mistake}
                          </div>
                          <div className="mt-4 text-sm text-red-600/70 dark:text-red-300/70 italic">
                            Review your connections and component properties to fix the issue.
                          </div>
                        </div>
                      )}
                    </div>

                    {/* Right Column: Visualization */}
                    {(analysisResult.imageUrl || isRenderingImage || imageError) && (
                      <div className="flex-1 flex flex-col gap-3">
                        <div className="bg-zinc-50 dark:bg-zinc-900 p-6 rounded-2xl border border-zinc-200 dark:border-white/10 h-full flex flex-col">
                          <h3 className="mt-0 mb-4 text-lg font-semibold text-zinc-700 dark:text-zinc-200">
                            Visual Output
                          </h3>
                          <div className="flex-1 flex items-center justify-center bg-white dark:bg-zinc-950 rounded-xl overflow-hidden min-h-[240px]">
                            {analysisResult.imageUrl ? (
                              <img
                                src={analysisResult.imageUrl}
                                alt="AI-rendered illustration of the experiment outcome"
                                className="max-w-full max-h-[420px] object-contain"
                              />
                            ) : isRenderingImage ? (
                              <div className="flex flex-col items-center gap-3 py-10">
                                <div className="w-10 h-10 border-4 border-zinc-200 dark:border-white/10 border-t-orange-500 rounded-full animate-spin" />
                                <div className="text-sm font-medium text-zinc-500 dark:text-zinc-400">Painting your result...</div>
                                <div className="text-xs text-zinc-400 dark:text-zinc-500">This can take up to a minute.</div>
                              </div>
                            ) : (
                              <div className="text-sm text-zinc-400 dark:text-zinc-500 py-10">{imageError}</div>
                            )}
                          </div>
                        </div>
                      </div>
                    )}
                  </>
                ) : (
                  <div className="w-full h-full flex flex-col items-center justify-center gap-5">
                    <div className="w-14 h-14 border-[6px] border-zinc-200 dark:border-white/10 border-t-orange-500 rounded-full animate-spin" />
                    <div className="text-lg text-zinc-500 dark:text-zinc-400 font-medium">Processing your experiment...</div>
                  </div>
                )}
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Welcome Modal */}
      <AnimatePresence>
        {showWelcomeModal && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-[1000] p-4"
          >
            <motion.div
              initial={{ opacity: 0, y: 20, scale: 0.97 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: 20, scale: 0.97 }}
              transition={{ duration: 0.2 }}
              className="bg-white dark:bg-zinc-950 border border-zinc-200 dark:border-white/10 p-8 rounded-3xl w-full max-w-[600px] max-h-[85vh] overflow-y-auto shadow-[0_20px_60px_rgba(0,0,0,0.25)] dark:shadow-[0_20px_60px_rgba(0,0,0,0.7)]"
            >
              <h2 className="font-serif text-3xl text-zinc-900 dark:text-white mb-3">
                Welcome to <span className="text-orange-500">AI Experiment Lab</span>
              </h2>
              <p className="mb-6 text-[15px] text-zinc-500 dark:text-zinc-400 leading-relaxed">
                Build and simulate complex experiments using a visual canvas powered by AI.
              </p>

              <div className="mb-6">
                <h3 className="text-base font-semibold text-zinc-800 dark:text-zinc-200 mb-3">How to use</h3>
                <ol className="m-0 pl-5 text-sm text-zinc-500 dark:text-zinc-400 leading-loose list-decimal">
                  <li>Browse the <strong className="text-zinc-800 dark:text-zinc-200">1000+ components</strong> in the left sidebar</li>
                  <li><strong className="text-zinc-800 dark:text-zinc-200">Drag components</strong> onto the canvas</li>
                  <li><strong className="text-zinc-800 dark:text-zinc-200">Connect components</strong> by dragging from output (orange) to input (blue)</li>
                  <li><strong className="text-zinc-800 dark:text-zinc-200">Double-click nodes</strong> to edit their labels</li>
                  <li><strong className="text-zinc-800 dark:text-zinc-200">Click connections</strong> to add labels/conditions</li>
                  <li>Click <strong className="text-zinc-800 dark:text-zinc-200">"Run Experiment"</strong> to analyze with AI</li>
                  <li><strong className="text-zinc-800 dark:text-zinc-200">Export/Import</strong> your experiments as JSON</li>
                </ol>
              </div>

              <div className="p-4 bg-orange-50 dark:bg-orange-500/10 border border-orange-200 dark:border-orange-500/20 rounded-2xl mb-6">
                <p className="m-0 text-[13px] text-orange-800/90 dark:text-orange-200/90">
                  <strong>Important:</strong> AI-powered experiment analysis runs on our hosted OpenAI-compatible backend.
                  No additional API key setup is needed.
                </p>
              </div>

              <div className="grid grid-cols-2 gap-3 mb-6">
                {[
                  { icon: <Zap size={22} />, label: 'Electronics', count: '300+ components', color: 'text-blue-500 dark:text-blue-400', bg: 'bg-blue-50 dark:bg-blue-500/10' },
                  { icon: <FlaskConical size={22} />, label: 'Chemistry', count: '200+ components', color: 'text-emerald-500 dark:text-emerald-400', bg: 'bg-emerald-50 dark:bg-emerald-500/10' },
                  { icon: <Atom size={22} />, label: 'Physics', count: '250+ components', color: 'text-violet-500 dark:text-violet-400', bg: 'bg-violet-50 dark:bg-violet-500/10' },
                  { icon: <Code2 size={22} />, label: 'Coding', count: '200+ components', color: 'text-orange-500 dark:text-orange-400', bg: 'bg-orange-50 dark:bg-orange-500/10' },
                ].map((cat) => (
                  <div key={cat.label} className={`p-3.5 rounded-2xl ${cat.bg} border border-zinc-200/60 dark:border-white/5`}>
                    <div className={`mb-2 ${cat.color}`}>{cat.icon}</div>
                    <div className="text-[13px] font-semibold text-zinc-900 dark:text-zinc-100">{cat.label}</div>
                    <div className="text-[11px] text-zinc-500">{cat.count}</div>
                  </div>
                ))}
              </div>

              <div className="flex gap-3 justify-end">
                <button
                  onClick={() => {
                    handleCloseWelcome();
                    setShowExamplesModal(true);
                  }}
                  className="px-5 py-2.5 rounded-full bg-zinc-100 dark:bg-white/5 text-zinc-600 dark:text-zinc-300 hover:bg-zinc-200 dark:hover:bg-white/10 hover:text-zinc-900 dark:hover:text-white text-sm font-medium transition-colors"
                >
                  View Examples
                </button>
                <button
                  onClick={handleCloseWelcome}
                  className="px-5 py-2.5 rounded-full bg-orange-500 text-white hover:bg-orange-600 text-sm font-medium shadow-[0_4px_16px_rgba(255,79,0,0.35)] transition-colors"
                >
                  Get Started
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Examples Modal */}
      <AnimatePresence>
        {showExamplesModal && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-[1000] p-4"
          >
            <motion.div
              initial={{ opacity: 0, y: 20, scale: 0.97 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: 20, scale: 0.97 }}
              transition={{ duration: 0.2 }}
              className="bg-white dark:bg-zinc-950 border border-zinc-200 dark:border-white/10 p-7 rounded-3xl w-full max-w-[500px] shadow-[0_20px_60px_rgba(0,0,0,0.25)] dark:shadow-[0_20px_60px_rgba(0,0,0,0.7)]"
            >
              <h2 className="font-serif text-2xl text-zinc-900 dark:text-white mb-2">
                Example Experiments
              </h2>
              <p className="mb-5 text-sm text-zinc-500 dark:text-zinc-400">
                Load a pre-built experiment to get started quickly
              </p>

              <div className="flex flex-col gap-2.5 mb-6 max-h-[50vh] overflow-y-auto pr-1">
                {EXAMPLE_LIST.map((example) => (
                  <button
                    key={example.id}
                    onClick={() => handleLoadExample(example.id)}
                    className="p-4 bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-white/10 rounded-2xl text-left transition-colors hover:border-orange-500/50 hover:bg-orange-50/60 dark:hover:bg-zinc-800/80"
                  >
                    <div className="text-sm font-semibold text-zinc-900 dark:text-zinc-100 mb-1">
                      {example.name}
                    </div>
                    <div className="text-xs text-zinc-500">
                      {example.category}
                    </div>
                  </button>
                ))}
              </div>

              <div className="flex justify-end">
                <button
                  onClick={() => setShowExamplesModal(false)}
                  className="px-5 py-2.5 rounded-full bg-zinc-100 dark:bg-white/5 text-zinc-600 dark:text-zinc-300 hover:bg-zinc-200 dark:hover:bg-white/10 hover:text-zinc-900 dark:hover:text-white text-sm font-medium transition-colors"
                >
                  Close
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* API Key Modal */}
      <AnimatePresence>
        {showApiKeyModal && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-[1000] p-4"
          >
            <motion.div
              initial={{ opacity: 0, y: 20, scale: 0.97 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: 20, scale: 0.97 }}
              transition={{ duration: 0.2 }}
              className="bg-white dark:bg-zinc-950 border border-zinc-200 dark:border-white/10 p-7 rounded-3xl w-full max-w-[500px] shadow-[0_20px_60px_rgba(0,0,0,0.25)] dark:shadow-[0_20px_60px_rgba(0,0,0,0.7)]"
            >
              <h2 className="font-serif text-2xl text-zinc-900 dark:text-white mb-2">
                Configure API Key
              </h2>
              <p className="mb-4 text-sm text-zinc-500 dark:text-zinc-400">
                AI-powered experiment analysis runs on our hosted backend. No additional configuration is needed.
              </p>
              <input
                type="password"
                value={apiKey}
                onChange={(e) => setApiKey(e.target.value)}
                placeholder="Enter your API key..."
                className="w-full px-3.5 py-3 bg-zinc-100 dark:bg-zinc-900 border border-zinc-200 dark:border-white/10 rounded-xl text-sm text-zinc-900 dark:text-zinc-100 mb-4 outline-none focus:border-orange-500/60 transition-colors box-border"
              />
              <div className="flex gap-2.5 justify-end">
                <button
                  onClick={() => setShowApiKeyModal(false)}
                  className="px-5 py-2.5 rounded-full bg-zinc-100 dark:bg-white/5 text-zinc-600 dark:text-zinc-300 hover:bg-zinc-200 dark:hover:bg-white/10 hover:text-zinc-900 dark:hover:text-white text-sm font-medium transition-colors"
                >
                  Cancel
                </button>
                <button
                  onClick={() => {
                    if (apiKey) {
                      localStorage.setItem('aiexp-api-key', apiKey);
                      setShowApiKeyModal(false);
                      showToast('API key saved successfully!', 'success');
                    } else {
                      showToast('Please enter an API key', 'error');
                    }
                  }}
                  className="px-5 py-2.5 rounded-full bg-orange-500 text-white hover:bg-orange-600 text-sm font-medium shadow-[0_4px_16px_rgba(255,79,0,0.35)] transition-colors"
                >
                  Save
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Robot Assistant Chatbot */}
      <RobotAssistant
        experimentJSON={generateExperimentJSON(nodes, edges)}
        onRequestHint={handleRequestHint}
      />

      <PromptDialog state={promptState} onClose={() => setPromptState(null)} />
      <ToastStack toasts={toasts} onDismiss={dismissToast} />
    </div>
  );
}

export default App;
