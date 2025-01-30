# Performance

The primary method of improving build performance is essentially avoiding `tsc`, the TypeScript compiler, as much as possible.

There are 3 main goals of `ts_project`, where `tsc` is the traditional tool:
* transpile TypeScript to javascript files
* transpile TypeScript to declaration files
* type-check TypeScript

## Transpilers

The easiest and most common performance improvement is to use a transpiler other than `tsc` for the transpiling
of TypeScript to javascript files. See [transpiler.md](transpiler.md) for details.

## Isolated Typecheck

Isolating the type-check action from the transpiling actions can also improve performance.

The tsconfig `compilerOptions.isolatedDeclarations` option ensures TypeScript code can be transpiled
to declaration files without the need for dependencies to be present.

The `ts_project(isolated_typecheck)` option can take advantage of `isolatedDeclarations` by separating the
transpiling vs type-checking into separate bazel actions. The transpiling of TypeScript files with `isolatedDeclarations`
can be done without blocking waiting for dependencies, greatly increasing parallelization of declaration file creation.
Declaration files being created faster then allows the type-checking to start sooner.

### When to use `isolated_typecheck`

It is not always possible or convenient to use the TypeScript `isolatedDeclarations` option, especially when it requires
significant code changes. However it may be worth enabling `isolatedDeclarations` for a subset of projects that are bottlenecks
in the build graph.

Bottlenecks in the build graph are normally targets with a lot of dependencies (including transitive), while also being depended
on by a lot of targets (including transitive).

In this example scenario C is a bottleneck in the build graph:
```
┌─────┐             ┌─────┐        
│  A  ┼────┐    ┌───►  D  │        
└─────┘    │    │   └─────┘        
┌─────┐   ┌▼────┤   ┌─────┐ ┌─────┐
│  B  ┼───►  C  ┼───►  E  ┼─►  F  │
└─────┘   └─────┘   └─────┘ └─────┘
```

Without `isolated_typecheck` transpiling declaration files follows the dependency graph. Project (A) and (B) require declaration
files outputted from (C). Project (C) requires declaration files outputted from (D), (E), and (F) etc.

With `isolated_typecheck` on module C more can be parallelized:
```
┌─────┐          
│  A  ┼────┐     
└─────┘    │     
┌─────┐   ┌▼────┐
│  B  ┼───►  C  │
└─────┘   └─────┘
┌─────┐          
│  D  │          
└─────┘          
┌─────┐   ┌─────┐  
│  E  ┼───►  F  │  
└─────┘   └─────┘  
```

The additional parallelization will also lead to type-checking starting sooner.
