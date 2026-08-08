import { NextRequest, NextResponse } from "next/server";
import { getSubmissions, createSubmission } from "@/lib/hackathonStore";

export async function GET(req: NextRequest, { params }: { params: { id: string } }) {
  try {
    const submissions = getSubmissions(params.id);
    return NextResponse.json({ success: true, submissions });
  } catch (error) {
    console.error("Error fetching submissions:", error);
    return NextResponse.json({ success: false, error: "Failed to fetch submissions" }, { status: 500 });
  }
}

export async function POST(req: NextRequest, { params }: { params: { id: string } }) {
  try {
    const { userId, userName, title, description, githubLink, demoLink } = await req.json();

    if (!userId || !userName || !title || !description || !githubLink) {
      return NextResponse.json(
        { success: false, error: "Missing required fields" },
        { status: 400 }
      );
    }

    const submission = createSubmission({
      problemId: params.id,
      userId,
      userName,
      title,
      description,
      githubLink,
      demoLink,
    });

    return NextResponse.json({ success: true, submission });
  } catch (error) {
    console.error("Error creating submission:", error);
    return NextResponse.json({ success: false, error: "Failed to create submission" }, { status: 500 });
  }
}
