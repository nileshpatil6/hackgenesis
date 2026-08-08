import { NextRequest, NextResponse } from "next/server";
import { getRoomById } from "@/lib/voomStore";

export async function GET(req: NextRequest, { params }: { params: { id: string } }) {
  try {
    const room = getRoomById(params.id);
    if (!room) {
      return NextResponse.json({ success: false, error: "Room not found" }, { status: 404 });
    }
    return NextResponse.json({ success: true, room });
  } catch (error) {
    console.error("Error fetching voom room:", error);
    return NextResponse.json({ success: false, error: "Failed to fetch room" }, { status: 500 });
  }
}
