import { NextRequest, NextResponse } from "next/server";
import { getUserProgress } from "@/lib/voomStore";

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const roomId = searchParams.get("roomId");
    const userId = searchParams.get("userId");

    if (!roomId || !userId) {
      return NextResponse.json(
        { success: false, error: "roomId and userId are required" },
        { status: 400 }
      );
    }

    const progress = getUserProgress(roomId, userId);

    return NextResponse.json({
      success: true,
      progress: {
        questionsSolved: progress?.questionsSolved || [],
        totalPoints: progress?.totalPoints || 0,
      },
    });
  } catch (error) {
    console.error("Error fetching voom progress:", error);
    return NextResponse.json(
      { success: false, error: "Failed to fetch progress" },
      { status: 500 }
    );
  }
}
