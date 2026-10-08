import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { cacheLife, cacheTag } from 'next/cache';

const read = async (file: string) =>
	JSON.parse(await readFile(path.join(process.cwd(), 'data', file), 'utf8'));

export async function getNode(uri: string) {
	'use cache';
	cacheLife('max');
	const nodes = { '/a/': 'A', ...(await read('nodes.json')) };
	cacheTag(nodes[uri] ? `node:${uri}` : 'uris', 'nodes');
	return nodes[uri] ? { title: nodes[uri] as string } : null;
}

export async function getRedirection(uri: string) {
	'use cache';
	cacheLife('max');
	cacheTag(`redirect:${uri}`, 'nodes', 'redirects');
	const all = await read('redirects.json');
	return (all[uri] as string | undefined) ?? null;
}
