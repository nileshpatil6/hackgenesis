import { NextRequest, NextResponse } from "next/server";
import { submitSolve } from "@/lib/voomStore";

export async function POST(req: NextRequest) {
  try {
    const { roomId, questionId, userId, userName, pointsEarned } = await req.json();

    if (!roomId || !questionId || !userId || !userName) {
      return NextResponse.json(
        { success: false, error: "Missing required fields" },
        { status: 400 }
      );
    }

    const result = submitSolve({ roomId, questionId, userId, userName, pointsEarned: pointsEarned || 0 });

    if (!result.success) {
      return NextResponse.json(
        { success: false, error: result.error || "Failed to submit solution" },
        { status: 400 }
      );
    }

    return NextResponse.json({
      success: true,
      message: "Submission recorded successfully",
    });
  } catch (error) {
    console.error("Error submitting solution:", error);
    return NextResponse.json(
      { success: false, error: "Failed to submit solution" },
      { status: 500 }
    );
  }
}
