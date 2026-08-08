import { NextResponse } from "next/server";
import { getRooms } from "@/lib/voomStore";

export async function GET() {
  try {
    const rooms = getRooms();
    return NextResponse.json({ success: true, rooms });
  } catch (error) {
    console.error("Error fetching voom rooms:", error);
    return NextResponse.json({ success: false, error: "Failed to fetch rooms" }, { status: 500 });
  }
}
