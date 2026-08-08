import { NextRequest, NextResponse } from "next/server";
import { getProblemById } from "@/lib/hackathonStore";

export async function GET(req: NextRequest, { params }: { params: { id: string } }) {
  try {
    const problem = getProblemById(params.id);
    if (!problem) {
      return NextResponse.json({ success: false, error: "Problem not found" }, { status: 404 });
    }
    return NextResponse.json({ success: true, problem });
  } catch (error) {
    console.error("Error fetching hackathon problem:", error);
    return NextResponse.json({ success: false, error: "Failed to fetch problem" }, { status: 500 });
  }
}
