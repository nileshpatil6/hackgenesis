import { useCallback, useRef, useState, useEffect } from 'react';
import { X } from 'lucide-react';
import { Point, DrawnShape, DrawingTool } from '../types/drawing';
import { shapeRecognizer } from '../utils/shapeRecognition';

interface DrawingCanvasProps {
  onShapeComplete: (shape: DrawnShape) => void;
  currentTool: DrawingTool | null;
  onRequestLabel: (title: string, defaultValue: string, onConfirm: (label: string) => void) => void;
  onUnrecognizedShape: () => void;
  onCancel: () => void;
}

export function DrawingCanvas({ onShapeComplete, currentTool, onRequestLabel, onUnrecognizedShape, onCancel }: DrawingCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const overlayRef = useRef<HTMLDivElement>(null);
  const [isDrawing, setIsDrawing] = useState(false);
  const [rawPoints, setRawPoints] = useState<Point[]>([]);

  const drawPoints = useCallback((points: Point[], ctx: CanvasRenderingContext2D) => {
    if (points.length < 1) return;

    ctx.strokeStyle = '#ef4444';
    ctx.lineWidth = 3;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

    if (points.length === 1) {
      // Draw a single point as a small circle
      ctx.beginPath();
      ctx.arc(points[0].x, points[0].y, 2, 0, 2 * Math.PI);
      ctx.fillStyle = '#ef4444';
      ctx.fill();
      return;
    }

    ctx.beginPath();
    ctx.moveTo(points[0].x, points[0].y);
    
    for (let i = 1; i < points.length; i++) {
      ctx.lineTo(points[i].x, points[i].y);
    }
    
    ctx.stroke();
  }, []);

  const drawPerfectShape = useCallback((points: Point[], ctx: CanvasRenderingContext2D) => {
    ctx.strokeStyle = '#10b981';
    ctx.fillStyle = 'rgba(16, 185, 129, 0.1)';
    ctx.lineWidth = 3;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

    ctx.beginPath();
    ctx.moveTo(points[0].x, points[0].y);
    
    for (let i = 1; i < points.length; i++) {
      ctx.lineTo(points[i].x, points[i].y);
    }
    
    ctx.stroke();
    ctx.fill();
  }, []);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const updateSize = () => {
      if (overlayRef.current && overlayRef.current.parentElement) {
        const parent = overlayRef.current.parentElement;
        canvas.width = parent.clientWidth;
        canvas.height = parent.clientHeight;
      } else {
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
      }
      
      // Re-draw if we have points
      if (rawPoints.length > 0) {
        const ctx = canvas.getContext('2d');
        if (ctx) {
          drawPoints(rawPoints, ctx);
        }
      }
    };

    updateSize();
    window.addEventListener('resize', updateSize);

    return () => window.removeEventListener('resize', updateSize);
  }, [rawPoints, drawPoints]);

  // Escape always gets you out of draw mode, even mid-stroke.
  useEffect(() => {
    if (!currentTool) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setIsDrawing(false);
        setRawPoints([]);
        onCancel();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [currentTool, onCancel]);

  const handleMouseDown = useCallback((e: React.MouseEvent<HTMLDivElement>) => {
    if (!currentTool) return;

    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const rect = overlayRef.current?.getBoundingClientRect();
    if (!rect) return;

    const pos = {
      x: e.clientX - rect.left,
      y: e.clientY - rect.top,
    };
    
    setIsDrawing(true);
    setRawPoints([pos]);
    
    // Draw the initial point
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    drawPoints([pos], ctx);
  }, [currentTool, drawPoints]);

  const handleMouseMove = useCallback((e: React.MouseEvent<HTMLDivElement>) => {
    if (!isDrawing || !currentTool) return;

    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const rect = overlayRef.current?.getBoundingClientRect();
    if (!rect) return;

    const pos = {
      x: e.clientX - rect.left,
      y: e.clientY - rect.top,
    };
    
    const newPoints = [...rawPoints, pos];
    setRawPoints(newPoints);
    
    // Clear and redraw
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    drawPoints(newPoints, ctx);
  }, [isDrawing, currentTool, rawPoints, drawPoints]);

  const handleMouseUp = useCallback(() => {
    if (!isDrawing || !currentTool || rawPoints.length < 3) {
      setIsDrawing(false);
      setRawPoints([]);
      return;
    }

    setIsDrawing(false);

    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Recognize the shape
    const analysis = shapeRecognizer.recognizeShape(rawPoints);
    
    if (analysis.type !== 'unknown' && analysis.confidence > 0.6) {
      // Clear and draw the perfect shape
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      drawPerfectShape(analysis.points, ctx);

      // Show a brief success indicator
      setTimeout(() => {
        ctx.clearRect(0, 0, canvas.width, canvas.height);

        onRequestLabel(`Enter a label for this ${analysis.type}:`, analysis.type.charAt(0).toUpperCase() + analysis.type.slice(1), (label) => {
          if (!label.trim()) return;
          const shape: DrawnShape = {
            id: `shape_${Date.now()}`,
            type: analysis.type as any,
            points: analysis.points,
            bounds: analysis.bounds,
            label: label.trim(),
            recognized: true,
          };

          onShapeComplete(shape);
        });
      }, 500);
    } else {
      // Clear canvas if shape not recognized
      ctx.clearRect(0, 0, canvas.width, canvas.height);

      onUnrecognizedShape();
    }

    setRawPoints([]);
  }, [isDrawing, currentTool, rawPoints, drawPerfectShape, onShapeComplete, onRequestLabel, onUnrecognizedShape]);

  if (!currentTool) {
    return null;
  }

  return (
    <div
      ref={overlayRef}
      onMouseDown={handleMouseDown}
      onMouseMove={handleMouseMove}
      onMouseUp={handleMouseUp}
      onMouseLeave={handleMouseUp}
      style={{
        position: 'absolute',
        top: 0,
        left: 0,
        width: '100%',
        height: '100%',
        cursor: 'crosshair',
        pointerEvents: 'auto',
        zIndex: 2000,
        backgroundColor: 'transparent',
      }}
    >
      <canvas
        ref={canvasRef}
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          width: '100%',
          height: '100%',
          pointerEvents: 'none',
          zIndex: 2001,
        }}
      />
      <div
        className="absolute top-5 left-1/2 -translate-x-1/2 bg-white/95 dark:bg-zinc-900/95 backdrop-blur-md border border-zinc-200 dark:border-white/10 shadow-[0_8px_28px_rgba(0,0,0,0.15)] dark:shadow-[0_8px_28px_rgba(0,0,0,0.5)] flex items-center gap-3 px-6 py-3 rounded-full"
        style={{ zIndex: 2002 }}
      >
        <div className="w-3 h-3 rounded-full bg-orange-500 shadow-[0_0_0_2px_rgba(255,79,0,0.25)]" />
        <div>
          <div className="text-sm font-semibold text-zinc-900 dark:text-zinc-50">
            {currentTool === 'freehand' ? 'Freehand Drawing' : `Drawing ${currentTool.charAt(0).toUpperCase() + currentTool.slice(1)}`}
          </div>
          <div className="text-xs text-zinc-500 dark:text-zinc-400">
            Draw on the whiteboard • Esc to cancel
          </div>
        </div>
        <button
          onClick={() => {
            setIsDrawing(false);
            setRawPoints([]);
            onCancel();
          }}
          title="Cancel drawing"
          className="w-7 h-7 flex items-center justify-center rounded-full bg-zinc-100 dark:bg-white/10 text-zinc-500 dark:text-zinc-400 hover:bg-zinc-200 dark:hover:bg-white/20 hover:text-zinc-900 dark:hover:text-white transition-colors"
        >
          <X size={14} />
        </button>
      </div>
    </div>
  );
}
