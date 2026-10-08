import { notFound, permanentRedirect } from 'next/navigation';
import { getNode, getRedirection } from '../lookups';

export async function generateStaticParams() {
	return [{ uri: ['a'] }];
}

export default async function Page({
	params,
}: {
	params: Promise<{ uri?: string[] }>;
}) {
	const { uri: segments } = await params;
	const uri = `/${(segments ?? []).join('/')}/`.replace(/\/+/g, '/');
	const node = await getNode(uri);
	if (!node) {
		const redirection = await getRedirection(uri);
		if (redirection) permanentRedirect(redirection);
		return notFound();
	}
	return <h1>{node.title}</h1>;
}
