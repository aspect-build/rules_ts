import pkg from '@aspect-test/e/package.json' with { type: "json" };

export const a: string = `Hello from ${pkg.name}@${pkg.version}`;
