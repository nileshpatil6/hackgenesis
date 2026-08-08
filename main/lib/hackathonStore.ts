import crypto from "crypto";
import { readJSON, writeJSON } from "./localDb";

export interface HackathonProblem {
  id: string;
  title: string;
  description: string;
  category: string;
  difficulty: "Beginner" | "Intermediate" | "Advanced";
  postedBy: string;
  organization: string;
  tags: string[];
  prize?: string;
  deadline?: string;
  detailedDescription: string;
  requirements: string[];
  resources: string[];
  evaluationCriteria: string[];
}

export interface HackathonSubmission {
  id: string;
  problemId: string;
  userId: string;
  userName: string;
  title: string;
  description: string;
  githubLink: string;
  demoLink?: string;
  votes: number;
  createdAt: string;
}

const PROBLEMS_FILE = "hackathon-problems.json";
const SUBMISSIONS_FILE = "hackathon-submissions.json";

const PROBLEM_SEEDS: HackathonProblem[] = [
  {
    id: "1",
    title: "Climate Change Prediction Model",
    description: "Develop a machine learning model to predict climate patterns and temperature changes based on historical data. Help scientists understand future climate scenarios.",
    category: "Environment",
    difficulty: "Advanced",
    postedBy: "Dr. Sarah Johnson",
    organization: "NASA Climate Research",
    tags: ["Machine Learning", "Climate Science", "Data Analysis"],
    prize: "₹50,000",
    deadline: "2025-12-31",
    detailedDescription: `Climate change is one of the most pressing challenges of our time. This project aims to develop sophisticated machine learning models that can predict future climate patterns based on historical data spanning the last century.

Your solution should analyze various factors including:
- Temperature variations across different regions
- Greenhouse gas emissions
- Ocean temperature changes
- Ice cap measurements
- Atmospheric CO2 levels

The model should be able to predict climate patterns for the next 50 years with reasonable accuracy and provide insights that can help policymakers and researchers make informed decisions.`,
    requirements: [
      "Use at least 3 different machine learning algorithms (LSTM, Random Forest, Neural Networks recommended)",
      "Train on historical climate data from at least 50 years",
      "Achieve minimum 75% prediction accuracy on test data",
      "Provide clear visualizations of predictions",
      "Include uncertainty estimates in predictions",
      "Document your methodology thoroughly",
    ],
    resources: [
      "NOAA Climate Data: https://www.ncdc.noaa.gov/data-access",
      "NASA Climate Data: https://climate.nasa.gov/vital-signs/",
      "Kaggle Climate Datasets",
      "IPCC Reports for validation",
    ],
    evaluationCriteria: [
      "Model Accuracy (40%)",
      "Innovation in Approach (25%)",
      "Code Quality and Documentation (20%)",
      "Visualization and Presentation (15%)",
    ],
  },
  {
    id: "2",
    title: "Water Quality Monitoring System",
    description: "Create an IoT-based solution to monitor water quality in real-time across rural areas. Detect contamination and alert authorities automatically.",
    category: "Environment",
    difficulty: "Intermediate",
    postedBy: "Prof. Rajesh Kumar",
    organization: "Indian Institute of Science",
    tags: ["IoT", "Sensors", "Water Management"],
    prize: "₹30,000",
    deadline: "2025-11-30",
    detailedDescription: `Access to clean water is crucial for public health. This project requires developing an IoT-based system that can monitor water quality parameters in real-time and alert authorities when contamination is detected.

The system should monitor:
- pH levels
- Turbidity
- Dissolved oxygen
- Temperature
- Presence of harmful bacteria or chemicals

The solution should be cost-effective, easy to deploy in remote areas, and provide real-time alerts through mobile applications.`,
    requirements: [
      "Design sensor array for water quality parameters",
      "Implement real-time data transmission",
      "Create mobile/web dashboard for monitoring",
      "Set up automatic alert system",
      "Ensure system works in low-power conditions",
      "Make it affordable (target cost < ₹10,000 per unit)",
    ],
    resources: [
      "Arduino/Raspberry Pi documentation",
      "Water quality standards: WHO guidelines",
      "IoT communication protocols: MQTT, LoRaWAN",
      "Sample datasets for testing",
    ],
    evaluationCriteria: [
      "Sensor Accuracy (30%)",
      "System Reliability (25%)",
      "Cost Effectiveness (20%)",
      "User Interface (15%)",
      "Scalability (10%)",
    ],
  },
  {
    id: "3",
    title: "AI-Powered Disease Diagnosis",
    description: "Build an AI system that can diagnose common diseases from medical images and symptoms. Focus on accessibility for rural healthcare centers.",
    category: "Healthcare",
    difficulty: "Advanced",
    postedBy: "Dr. Priya Sharma",
    organization: "AIIMS Research Center",
    tags: ["AI", "Healthcare", "Computer Vision", "Medical Imaging"],
    prize: "₹75,000",
    deadline: "2026-01-15",
    detailedDescription: "Develop an AI system to assist healthcare workers in diagnosing diseases from medical images (X-rays, CT scans) and patient symptoms, making healthcare more accessible in rural areas.",
    requirements: [
      "Train on medical imaging datasets",
      "Achieve 85%+ accuracy",
      "Support multiple disease types",
      "Provide confidence scores",
      "HIPAA compliant",
    ],
    resources: ["NIH Medical Image Database", "Kaggle Medical Datasets", "TensorFlow/PyTorch tutorials"],
    evaluationCriteria: ["Accuracy (40%)", "Disease Coverage (25%)", "User Interface (20%)", "Performance (15%)"],
  },
  {
    id: "4",
    title: "Smart Traffic Management",
    description: "Design an intelligent traffic management system using computer vision to reduce congestion in urban areas and optimize traffic flow.",
    category: "Smart Cities",
    difficulty: "Intermediate",
    postedBy: "Dr. Amit Verma",
    organization: "IIT Delhi",
    tags: ["Computer Vision", "IoT", "Urban Planning"],
    prize: "₹40,000",
    deadline: "2025-12-15",
    detailedDescription: `Urban traffic congestion wastes millions of commuter-hours and increases emissions every year. This project asks you to build a computer-vision-driven traffic management system that reads live camera feeds at intersections, estimates vehicle density and flow direction, and dynamically adjusts signal timing to reduce congestion.

Your solution should handle multiple intersections, be robust to weather and lighting changes, and expose a dashboard traffic operators can use to monitor the network in real time.`,
    requirements: [
      "Detect and count vehicles per lane from camera footage in real time",
      "Dynamically adjust signal timing based on live traffic density",
      "Handle at least 4 intersections in a coordinated simulation",
      "Build an operator dashboard showing current flow and signal state",
      "Degrade gracefully under poor lighting/weather conditions",
      "Document expected latency and hardware requirements",
    ],
    resources: [
      "OpenCV and YOLO object detection tutorials",
      "SUMO traffic simulation toolkit",
      "Public traffic camera datasets (e.g. UA-DETRAC)",
      "IIT Delhi Urban Mobility research papers",
    ],
    evaluationCriteria: [
      "Detection Accuracy (30%)",
      "Congestion Reduction in Simulation (30%)",
      "System Robustness (20%)",
      "Dashboard Usability (20%)",
    ],
  },
  {
    id: "5",
    title: "Crop Disease Detection",
    description: "Develop a mobile app that uses AI to identify crop diseases from leaf images. Help farmers detect and treat diseases early to improve yield.",
    category: "Agriculture",
    difficulty: "Intermediate",
    postedBy: "Prof. Lakshmi Narayanan",
    organization: "Agricultural Research Institute",
    tags: ["Machine Learning", "Mobile Development", "Agriculture"],
    prize: "₹35,000",
    deadline: "2025-11-25",
    detailedDescription: `Crop diseases can devastate a farmer's yield if not caught early, and many smallholder farmers lack easy access to agronomists. This project asks you to build a mobile app where a farmer photographs a leaf and gets an instant diagnosis plus treatment guidance, working reliably even on low-end phones and patchy connectivity.`,
    requirements: [
      "Classify at least 10 common crop diseases from leaf photos",
      "Run inference on-device or with a lightweight backend for low-connectivity areas",
      "Achieve at least 80% classification accuracy",
      "Provide plain-language treatment recommendations",
      "Support offline photo capture with sync-when-connected",
      "Design for low-literacy users (icons, voice guidance a plus)",
    ],
    resources: [
      "PlantVillage leaf disease dataset",
      "TensorFlow Lite for on-device inference",
      "Agricultural Research Institute treatment guidelines",
      "Kaggle plant pathology datasets",
    ],
    evaluationCriteria: [
      "Classification Accuracy (35%)",
      "Offline/Low-Bandwidth Usability (25%)",
      "Treatment Guidance Quality (20%)",
      "UI Accessibility (20%)",
    ],
  },
  {
    id: "6",
    title: "Renewable Energy Optimizer",
    description: "Create a system to optimize the distribution and storage of renewable energy from solar and wind sources across smart grids.",
    category: "Energy",
    difficulty: "Advanced",
    postedBy: "Dr. Michael Chen",
    organization: "Renewable Energy Foundation",
    tags: ["Energy Management", "Optimization", "Smart Grid"],
    prize: "₹60,000",
    deadline: "2026-02-01",
    detailedDescription: `Solar and wind generation are inherently variable, which makes balancing supply, storage, and demand across a smart grid a hard optimization problem. Build a system that forecasts renewable generation, decides when to store versus dispatch energy, and minimizes both cost and curtailed (wasted) generation.`,
    requirements: [
      "Forecast solar/wind output using historical weather + generation data",
      "Optimize charge/discharge scheduling for battery storage",
      "Minimize curtailed renewable energy under variable demand",
      "Simulate at least a 7-day operating window with hourly resolution",
      "Report cost savings versus a naive baseline strategy",
      "Explain the optimization approach used (LP, MPC, RL, etc.)",
    ],
    resources: [
      "NREL renewable generation datasets",
      "Open-source grid simulation tools (PyPSA, GridLAB-D)",
      "Historical weather APIs for forecasting inputs",
      "Renewable Energy Foundation grid case studies",
    ],
    evaluationCriteria: [
      "Forecast Accuracy (25%)",
      "Optimization Effectiveness / Cost Savings (35%)",
      "Handling of Real-World Constraints (25%)",
      "Documentation and Reproducibility (15%)",
    ],
  },
  {
    id: "7",
    title: "Disaster Response Coordinator",
    description: "Build a real-time disaster response coordination platform that helps emergency services locate and assist affected populations during natural disasters.",
    category: "Emergency Management",
    difficulty: "Advanced",
    postedBy: "Dr. Anita Desai",
    organization: "National Disaster Management Authority",
    tags: ["Web Development", "Real-time Systems", "GIS"],
    prize: "₹55,000",
    deadline: "2025-12-20",
    detailedDescription: `During a natural disaster, the biggest bottleneck is often coordination, not resources: responders don't know where help is needed most, and affected people can't easily report their situation. Build a real-time platform where affected individuals can report their location/needs, and responders get a live prioritized map to coordinate rescue and aid.`,
    requirements: [
      "Allow affected users to submit location + need type (medical, shelter, food, rescue) even on weak connections",
      "Provide responders a live, filterable map of active requests",
      "Prioritize/cluster requests by severity and proximity to resources",
      "Support offline-first submission that syncs once connectivity returns",
      "Handle at least 1,000 concurrent reports without degrading",
      "Include a basic resource-assignment/status-tracking workflow",
    ],
    resources: [
      "Leaflet/Mapbox GIS libraries",
      "NDMA disaster response protocols",
      "WebSocket/real-time sync patterns (Firebase, Supabase Realtime)",
      "Public disaster response case studies (e.g. Kerala floods coordination apps)",
    ],
    evaluationCriteria: [
      "Real-World Usability Under Poor Connectivity (30%)",
      "Coordination/Prioritization Logic (30%)",
      "Scalability (20%)",
      "UI Clarity for High-Stress Use (20%)",
    ],
  },
  {
    id: "8",
    title: "Education Access Platform",
    description: "Develop a low-bandwidth educational platform that works offline and provides quality education content to remote areas with limited internet.",
    category: "Education",
    difficulty: "Intermediate",
    postedBy: "Prof. Kavita Rao",
    organization: "Digital Education Initiative",
    tags: ["Web Development", "Offline-First", "Education"],
    prize: "₹25,000",
    deadline: "2025-11-28",
    detailedDescription: `Millions of students in remote areas have limited or unreliable internet access, cutting them off from digital learning resources. Build an offline-first education platform that lets a student download lesson content once and continue learning, tracking progress, and taking quizzes entirely offline, syncing back whenever a connection is available.`,
    requirements: [
      "Support full offline access to downloaded lesson content",
      "Sync progress/quiz results automatically when back online",
      "Keep initial download size small enough for low-bandwidth areas",
      "Support at least one full subject's worth of structured content",
      "Work on low-end Android devices",
      "Include a simple teacher-facing view of student progress",
    ],
    resources: [
      "Service Worker / PWA offline caching guides",
      "OpenStax and other open educational resource libraries",
      "IndexedDB for local data persistence",
      "Digital Education Initiative content guidelines",
    ],
    evaluationCriteria: [
      "Offline Reliability (35%)",
      "Content Quality and Structure (25%)",
      "Performance on Low-End Devices (25%)",
      "Teacher Progress View (15%)",
    ],
  },
  {
    id: "9",
    title: "Wildlife Conservation Tracker",
    description: "Create an AI-powered system to track and monitor endangered species using camera traps and satellite imagery to aid conservation efforts.",
    category: "Wildlife",
    difficulty: "Advanced",
    postedBy: "Dr. Robert Williams",
    organization: "World Wildlife Fund",
    tags: ["Computer Vision", "AI", "Conservation"],
    prize: "₹45,000",
    deadline: "2026-01-10",
    detailedDescription: `Conservation teams collect huge volumes of camera-trap footage and satellite imagery that take far too long to review manually. Build a system that automatically identifies and counts endangered species in camera-trap images/video and flags anomalies (e.g. signs of poaching activity) from satellite imagery, so conservationists can focus their limited time where it matters most.`,
    requirements: [
      "Classify and count animals present in camera-trap images across at least 5 species",
      "Handle low-light/night-vision camera-trap footage",
      "Flag likely false triggers (wind, shadows) to reduce reviewer workload",
      "Provide a reviewer dashboard summarizing detections over time",
      "Document accuracy per species and known failure cases",
      "Consider edge deployment for remote camera sites with no connectivity",
    ],
    resources: [
      "LILA BC camera trap datasets",
      "Snapshot Serengeti dataset",
      "WWF conservation technology reports",
      "YOLO / MegaDetector for wildlife detection baselines",
    ],
    evaluationCriteria: [
      "Detection/Classification Accuracy (35%)",
      "False Positive Reduction (25%)",
      "Reviewer Dashboard Usability (20%)",
      "Feasibility for Field Deployment (20%)",
    ],
  },
  {
    id: "10",
    title: "Air Quality Prediction",
    description: "Develop a predictive model for air quality index in urban areas. Help citizens make informed decisions about outdoor activities and health.",
    category: "Environment",
    difficulty: "Intermediate",
    postedBy: "Dr. Sneha Patel",
    organization: "Environmental Research Institute",
    tags: ["Data Science", "Machine Learning", "Environmental Science"],
    prize: "₹30,000",
    deadline: "2025-12-05",
    detailedDescription: `Poor air quality is a serious public health risk, and forecasts help people plan around it (e.g. avoiding outdoor exercise on high-pollution days). Build a model that predicts a city's Air Quality Index (AQI) 24-72 hours ahead using historical pollution readings, weather data, and traffic/seasonal patterns, and present it through a citizen-friendly interface.`,
    requirements: [
      "Predict AQI 24-72 hours ahead for at least one city",
      "Use historical pollution + weather data as model inputs",
      "Achieve reasonable forecast accuracy (report MAE/RMSE against actuals)",
      "Present predictions with clear health guidance (safe/unsafe activity levels)",
      "Support multiple locations if time permits",
      "Explain which features most influence the forecast",
    ],
    resources: [
      "CPCB / OpenAQ air quality datasets",
      "Public weather APIs for meteorological features",
      "scikit-learn / Prophet / LSTM time-series tutorials",
      "WHO air quality guideline thresholds",
    ],
    evaluationCriteria: [
      "Forecast Accuracy (40%)",
      "Health Guidance Clarity (25%)",
      "Data Pipeline Quality (20%)",
      "Presentation (15%)",
    ],
  },
  {
    id: "11",
    title: "Blockchain for Supply Chain",
    description: "Implement a blockchain-based solution to track pharmaceutical supply chains and prevent counterfeit medicines from reaching consumers.",
    category: "Healthcare",
    difficulty: "Advanced",
    postedBy: "Dr. James Anderson",
    organization: "Pharmaceutical Research Council",
    tags: ["Blockchain", "Supply Chain", "Healthcare"],
    prize: "₹70,000",
    deadline: "2026-01-20",
    detailedDescription: `Counterfeit medicines are a serious global health hazard, especially where supply chains pass through many intermediaries. Build a blockchain-based tracking system that records each handoff of a pharmaceutical batch from manufacturer to pharmacy, letting any participant (including the end consumer) verify a medicine's authenticity and full chain of custody.`,
    requirements: [
      "Record batch creation and every custody transfer as an immutable on-chain event",
      "Support verification of a medicine's authenticity via a scannable code (QR/NFC)",
      "Design smart contracts for at least manufacturer, distributor, and pharmacy roles",
      "Detect and flag suspicious/duplicate batch scans",
      "Provide a simple consumer-facing verification interface",
      "Explain your choice of chain/network and its tradeoffs for this use case",
    ],
    resources: [
      "Ethereum/Hyperledger Fabric documentation",
      "Solidity smart contract tutorials",
      "WHO reports on counterfeit medicine prevalence",
      "Existing pharma traceability standards (e.g. GS1)",
    ],
    evaluationCriteria: [
      "Smart Contract Design and Security (30%)",
      "End-to-End Traceability (30%)",
      "Consumer Verification UX (20%)",
      "Documentation of Tradeoffs (20%)",
    ],
  },
  {
    id: "12",
    title: "Smart Waste Management",
    description: "Design an IoT-based smart waste management system that optimizes garbage collection routes and promotes recycling in cities.",
    category: "Smart Cities",
    difficulty: "Beginner",
    postedBy: "Prof. Meera Iyer",
    organization: "Urban Development Authority",
    tags: ["IoT", "Optimization", "Sustainability"],
    prize: "₹20,000",
    deadline: "2025-11-22",
    detailedDescription: `City waste collection routes are usually fixed schedules regardless of how full bins actually are, wasting fuel and truck time. Build a system where IoT fill-level sensors on bins feed a route-optimization backend, so collection trucks only visit bins that actually need emptying, on the shortest viable route.`,
    requirements: [
      "Simulate or read fill-level sensor data per bin",
      "Generate an optimized collection route covering only bins above a fill threshold",
      "Provide a dashboard showing bin status across the city",
      "Estimate fuel/time savings versus a fixed-route baseline",
      "Keep the sensor + backend design affordable for a city budget",
      "This is a Beginner-difficulty problem — a working prototype with a clear write-up is enough, production hardening is not required",
    ],
    resources: [
      "Basic IoT sensor + microcontroller docs (Arduino/ESP32)",
      "Route optimization basics (nearest-neighbor, OR-Tools)",
      "Urban Development Authority collection schedule data",
      "OpenStreetMap for routing",
    ],
    evaluationCriteria: [
      "Route Optimization Quality (30%)",
      "Dashboard Clarity (25%)",
      "Estimated Savings vs Baseline (25%)",
      "Overall Practicality (20%)",
    ],
  },
  {
    id: "13",
    title: "Mental Health Chatbot",
    description: "Build an AI chatbot that provides mental health support and resources. Make mental healthcare more accessible and reduce stigma.",
    category: "Healthcare",
    difficulty: "Intermediate",
    postedBy: "Dr. Emily Rodriguez",
    organization: "Mental Health Foundation",
    tags: ["NLP", "AI", "Healthcare", "Chatbot"],
    prize: "₹35,000",
    deadline: "2025-12-10",
    detailedDescription: `Stigma and access barriers keep many people from seeking mental health support. Build a conversational AI that offers a safe, supportive first point of contact — active listening, coping resources, and mood check-ins — while clearly recognizing when a situation needs escalation to a human professional or crisis line.`,
    requirements: [
      "Hold supportive, empathetic multi-turn conversations",
      "Recognize crisis-level language and immediately surface professional/crisis-line resources",
      "Never present itself as a substitute for professional therapy — be explicit about this",
      "Track mood check-ins over time for the user",
      "Keep all conversation data private and clearly explain your data-handling approach",
      "Document how you tested for and mitigated harmful/unsafe responses",
    ],
    resources: [
      "Crisis Text Line / iCall / national helpline resource lists",
      "OpenAI/Anthropic guidance on safety for mental-health-adjacent use cases",
      "Mental Health Foundation conversational design guidelines",
      "Published research on chatbot-assisted mental health support",
    ],
    evaluationCriteria: [
      "Safety and Crisis Handling (35%)",
      "Conversation Quality/Empathy (25%)",
      "Privacy Handling (20%)",
      "Resource Accuracy (20%)",
    ],
  },
  {
    id: "14",
    title: "Flood Prediction System",
    description: "Create an early warning system for floods using weather data, river levels, and machine learning to predict floods and save lives.",
    category: "Disaster Management",
    difficulty: "Advanced",
    postedBy: "Dr. Suresh Reddy",
    organization: "Meteorological Department",
    tags: ["Machine Learning", "Data Analysis", "Disaster Management"],
    prize: "₹50,000",
    deadline: "2025-12-28",
    detailedDescription: `Early flood warnings save lives, but require combining rainfall forecasts, river gauge levels, and terrain data into a timely, trustworthy prediction. Build a system that forecasts flood risk for a given river basin 12-48 hours ahead and issues clear, actionable warnings to at-risk communities.`,
    requirements: [
      "Combine rainfall, river level, and terrain/elevation data into a flood-risk model",
      "Forecast risk 12-48 hours ahead for at least one river basin",
      "Report accuracy against historical flood events",
      "Issue tiered warnings (e.g. watch/warning/emergency) rather than a single binary flag",
      "Design the alert delivery to work over SMS as well as an app (low-connectivity areas)",
      "Document your false-positive/false-negative tradeoffs — explain why you tuned it the way you did",
    ],
    resources: [
      "India Meteorological Department historical rainfall/river data",
      "Global Flood Awareness System (GloFAS) methodology",
      "USGS river gauge datasets (for reference methodology)",
      "SMS gateway APIs for alert delivery",
    ],
    evaluationCriteria: [
      "Prediction Accuracy on Historical Events (35%)",
      "Warning Tiering and Actionability (25%)",
      "Low-Connectivity Delivery Design (20%)",
      "Documentation of Tradeoffs (20%)",
    ],
  },
  {
    id: "15",
    title: "Sign Language Translator",
    description: "Develop a real-time sign language translation system using computer vision to help hearing-impaired individuals communicate more easily.",
    category: "Accessibility",
    difficulty: "Advanced",
    postedBy: "Prof. Linda Martinez",
    organization: "Accessibility Research Lab",
    tags: ["Computer Vision", "Machine Learning", "Accessibility"],
    prize: "₹40,000",
    deadline: "2026-01-05",
    detailedDescription: `Real-time sign language translation can remove a major communication barrier for hearing-impaired individuals in everyday interactions. Build a system that uses a webcam to recognize sign language gestures and translate them into text (and ideally speech) in real time, with low enough latency for a natural conversation.`,
    requirements: [
      "Recognize at least 50 common signs/words from live webcam video",
      "Translate to text in real time with low latency (target < 1s)",
      "Support continuous signing, not just isolated single-sign snapshots",
      "Provide clear visual feedback on recognition confidence",
      "Text-to-speech output is a strong plus, not mandatory",
      "Document accuracy per sign and known failure conditions (lighting, hand occlusion, etc.)",
    ],
    resources: [
      "WLASL (Word-Level American Sign Language) dataset",
      "MediaPipe Hands for hand landmark tracking",
      "Accessibility Research Lab sign language corpora",
      "Real-time inference optimization guides (ONNX, TensorRT)",
    ],
    evaluationCriteria: [
      "Recognition Accuracy (35%)",
      "Real-Time Latency (25%)",
      "Robustness to Real-World Conditions (20%)",
      "Accessibility of the Interface Itself (20%)",
    ],
  },
];

function loadProblems(): HackathonProblem[] {
  return readJSON<HackathonProblem[]>(PROBLEMS_FILE, PROBLEM_SEEDS);
}

function loadSubmissions(): HackathonSubmission[] {
  return readJSON<HackathonSubmission[]>(SUBMISSIONS_FILE, []);
}

export function getProblems(): Array<HackathonProblem & { submissions: number }> {
  const problems = loadProblems();
  const submissions = loadSubmissions();
  return problems.map((p) => ({
    ...p,
    submissions: submissions.filter((s) => s.problemId === p.id).length,
  }));
}

export function getProblemById(id: string): (HackathonProblem & { submissions: number }) | undefined {
  const problem = loadProblems().find((p) => p.id === id);
  if (!problem) return undefined;
  const submissions = loadSubmissions();
  return { ...problem, submissions: submissions.filter((s) => s.problemId === id).length };
}

export function getSubmissions(problemId: string): HackathonSubmission[] {
  return loadSubmissions()
    .filter((s) => s.problemId === problemId)
    .sort((a, b) => b.votes - a.votes);
}

export function createSubmission(params: {
  problemId: string;
  userId: string;
  userName: string;
  title: string;
  description: string;
  githubLink: string;
  demoLink?: string;
}): HackathonSubmission {
  const submissions = loadSubmissions();
  const submission: HackathonSubmission = {
    id: crypto.randomUUID(),
    problemId: params.problemId,
    userId: params.userId,
    userName: params.userName,
    title: params.title,
    description: params.description,
    githubLink: params.githubLink,
    demoLink: params.demoLink,
    votes: 0,
    createdAt: new Date().toISOString(),
  };
  submissions.push(submission);
  writeJSON(SUBMISSIONS_FILE, submissions);
  return submission;
}

export function voteSubmission(submissionId: string): { success: boolean; error?: string } {
  const submissions = loadSubmissions();
  const submission = submissions.find((s) => s.id === submissionId);
  if (!submission) {
    return { success: false, error: "Submission not found" };
  }
  submission.votes += 1;
  writeJSON(SUBMISSIONS_FILE, submissions);
  return { success: true };
}
