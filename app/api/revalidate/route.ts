import { revalidateTag } from 'next/cache';

export async function GET(request: Request) {
	const { searchParams } = new URL(request.url);
	const tag = searchParams.get('tag')!;
	revalidateTag(tag, searchParams.get('expire') ? { expire: 0 } : 'max');
	return Response.json({ tag });
}
