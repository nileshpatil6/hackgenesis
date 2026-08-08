import { NextRequest, NextResponse } from "next/server";
import { voteSubmission } from "@/lib/hackathonStore";

export async function POST(req: NextRequest, { params }: { params: { id: string } }) {
  try {
    const result = voteSubmission(params.id);
    if (!result.success) {
      return NextResponse.json({ success: false, error: result.error }, { status: 404 });
    }
    return NextResponse.json({ success: true });
  } catch (error) {
    console.error("Error voting on submission:", error);
    return NextResponse.json({ success: false, error: "Failed to vote" }, { status: 500 });
  }
}
