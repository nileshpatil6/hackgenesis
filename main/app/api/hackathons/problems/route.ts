import { NextResponse } from "next/server";
import { getProblems } from "@/lib/hackathonStore";

export async function GET() {
  try {
    const problems = getProblems();
    return NextResponse.json({ success: true, problems });
  } catch (error) {
    console.error("Error fetching hackathon problems:", error);
    return NextResponse.json({ success: false, error: "Failed to fetch problems" }, { status: 500 });
  }
}
