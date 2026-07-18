'use strict'
exports.__esModule = true
var path_1 = require('path')
// Resolve the tsconfig "extends" chain to a single config, equivalent to what
// `tsc --showConfig -p <tsconfig>` prints. Classic TypeScript (< 7) exposes the
// compiler API to node so this runs in-process; native TypeScript (>= 7) ships no
// JS API, so the same output is obtained by spawning the compiler CLI instead.
function resolveConfig(tsconfigPath) {
    var ts
    try {
        ts = require('typescript')
    } catch (e) {
        ts = null
    }
    if (ts && typeof ts.getParsedCommandLineOfConfigFile === 'function') {
        return resolveConfigViaApi(ts, tsconfigPath)
    }
    return resolveConfigViaShowConfig(tsconfigPath)
}
function resolveConfigViaApi(ts, tsconfigPath) {
    var diagnosticsHost = {
        getCurrentDirectory: function () {
            return ts.sys.getCurrentDirectory()
        },
        getNewLine: function () {
            return ts.sys.newLine
        },
        // Print filenames including their relativeRoot, so they can be located on
        // disk
        getCanonicalFileName: function (f) {
            return f
        },
    }
    var host = {
        fileExists: ts.sys.fileExists,
        readFile: ts.sys.readFile,
        readDirectory: ts.sys.readDirectory,
        getCurrentDirectory: function () {
            return ts.sys.getCurrentDirectory()
        },
        useCaseSensitiveFileNames: ts.sys.useCaseSensitiveFileNames,
        onUnRecoverableConfigFileDiagnostic: function (d) {
            throw new Error(
                tsconfigPath + ':' + ts.formatDiagnostic(d, diagnosticsHost)
            )
        },
    }
    var parsed = ts.getParsedCommandLineOfConfigFile(
        tsconfigPath,
        undefined,
        host
    )
    // We don't pass the srcs to this action, so it can't know if the program has the right sources.
    // error TS18002: The 'files' list in config file 'tsconfig.json' is empty.
    // error TS18003: No inputs were found in config file 'tsconfig.json'. Specified 'include'...
    var fatalErrors = parsed.errors.filter(function (e) {
        return e.code !== 18002 && e.code !== 18003
    })
    if (fatalErrors.length > 0)
        throw new Error(
            tsconfigPath +
                ':' +
                ts.formatDiagnostics(fatalErrors, diagnosticsHost)
        )
    var config = ts.convertToTSConfig(parsed, tsconfigPath, ts.sys)
    relativizeConfigPaths(config, tsconfigPath)
    // Only keep "files" when the original config specified it; a glob-based config
    // resolves it from this action's inputs (the tsconfig chain, not the srcs).
    if (!Array.isArray(parsed.raw && parsed.raw.files)) delete config.files
    return JSON.parse(JSON.stringify(config))
}
function resolveConfigViaShowConfig(tsconfigPath) {
    // require('typescript') is blocked by the native package's exports map, but
    // ./package.json is always resolvable; anchor the compiler CLI on it.
    var tscBin = path_1.join(
        path_1.dirname(require.resolve('typescript/package.json')),
        'bin',
        'tsc'
    )
    var stdout = require('child_process').execFileSync(
        process.execPath,
        [tscBin, '--project', tsconfigPath, '--showConfig'],
        { encoding: 'utf-8' }
    )
    var config = JSON.parse(stdout)
    relativizeConfigPaths(config, tsconfigPath)
    // "files" is resolved from this action's inputs, not the compile, and is never
    // validated, so drop it.
    delete config.files
    return JSON.parse(JSON.stringify(config))
}
// tsc materializes some paths as absolute, e.g. the implicit exclusion of outDir.
// Absolute paths under the execroot are not hermetic (sandbox paths differ across
// builds), so turn them back into paths relative to the config file.
// cwd is BAZEL_BINDIR (bazel-out/<config>/bin), three segments below the execroot.
function relativizeConfigPaths(config, tsconfigPath) {
    var configDir = path_1.dirname(path_1.resolve(tsconfigPath))
    var execroot = path_1.resolve(process.cwd(), '..', '..', '..')
    function relativize(p) {
        if (
            typeof p !== 'string' ||
            !path_1.isAbsolute(p) ||
            !p.startsWith(execroot + path_1.sep)
        ) {
            return p
        }
        var rel = path_1.relative(configDir, p)
        return rel.startsWith('..') ? rel : './' + rel
    }
    var arrayKeys = ['files', 'include', 'exclude']
    for (var i = 0; i < arrayKeys.length; i++) {
        var key = arrayKeys[i]
        if (Array.isArray(config[key])) {
            config[key] = config[key].map(relativize)
        }
    }
    if (Array.isArray(config.references)) {
        config.references = config.references.map(function (r) {
            return Object.assign({}, r, { path: relativize(r.path) })
        })
    }
    if (config.compilerOptions) {
        for (var option in config.compilerOptions) {
            var value = config.compilerOptions[option]
            if (typeof value === 'string') {
                config.compilerOptions[option] = relativize(value)
            } else if (Array.isArray(value)) {
                config.compilerOptions[option] = value.map(relativize)
            }
        }
    }
}
function main(_a) {
    var tsconfigPath = _a[0],
        output = _a[1],
        target = _a[2],
        packageDir = _a[3],
        attrsStr = _a[4]
    // The Bazel ts_project attributes were json-encoded
    // (on Windows the quotes seem to be quoted wrong, so replace backslash with quotes :shrug:)
    var attrs = JSON.parse(attrsStr.replace(/\\/g, '"'))
    // The resolved config, in `tsc --showConfig` shape. The checks below read this
    // JSON only, so they run identically whether it was resolved in-process or by
    // the native compiler CLI.
    var config = resolveConfig(tsconfigPath)
    var options = config.compilerOptions || {}
    var configDir = path_1.dirname(path_1.resolve(tsconfigPath))
    var failures = []
    var buildozerCmds = []
    function getTsOption(option) {
        if (typeof options[option] === 'string') {
            // Currently the only string-typed options are filepaths.
            // The resolved config states these relative to the config file, so when
            // echoing that back to the user, re-state them relative to the package.
            return path_1.relative(
                packageDir,
                path_1.resolve(configDir, options[option])
            )
        }
        return options[option]
    }
    function check(option, attr, isImplied) {
        attr = attr || option
        // treat compilerOptions undefined as false
        var optionVal = getTsOption(option)
        var match =
            optionVal === attrs[attr] ||
            (optionVal === undefined &&
                (attrs[attr] === false || attrs[attr] === '')) ||
            // The resolved config materializes options implied as computed defaults of
            // other options, e.g. composite implies declaration and incremental,
            // checkJs implies allowJs, and `module: nodenext` implies resolveJsonModule.
            // The attribute only needs to match what the tsconfig configures explicitly.
            (isImplied !== undefined &&
                optionVal === true &&
                attrs[attr] === false &&
                isImplied())
        if (!match) {
            failures.push(
                'attribute ' +
                    attr +
                    '=' +
                    attrs[attr] +
                    ' does not match compilerOptions.' +
                    option +
                    '=' +
                    optionVal
            )
            if (typeof optionVal === 'boolean') {
                buildozerCmds.push(
                    'set ' + attr + ' ' + (optionVal ? 'True' : 'False')
                )
            } else if (typeof optionVal === 'string') {
                buildozerCmds.push('set ' + attr + ' "' + optionVal + '"')
            } else if (optionVal === undefined) {
                // nothing to sync
            } else {
                throw new Error(
                    'cannot check option ' +
                        option +
                        ' of type ' +
                        typeof option
                )
            }
        }
    }
    function normalizeDirPath(p) {
        return p.replace(/\/+$/, '').replace(/^\.\//, '') || '.'
    }
    function check_out_dir(tsOption, attr) {
        var optionVal = getTsOption(tsOption)
        var attrVal = attrs[attr]
        var attrIsFalsyOrUndefined = attrVal === false || attrVal === '' || attrVal === undefined
        // When attr is set, use the raw tsconfig value (avoids path resolution/symlink issues).
        // When attr is empty, use the TypeScript-resolved value to catch tsconfig extends.
        var tsOptionValue = attrIsFalsyOrUndefined ? optionVal : (config.compilerOptions || {})[tsOption]
        var match = tsOptionValue === undefined || (attrIsFalsyOrUndefined
            ? tsOptionValue === attrVal
            : normalizeDirPath(String(tsOptionValue)) === normalizeDirPath(attrVal))
        if (!match) {
            throw new Error(
                `When ${tsOption} is set in the tsconfig it must also be set in the ts_project` +
                ` rule using ${attr}, so that the output directory is known to Bazel.\n\n` +
                'tsconfig:   ' + JSON.stringify(tsOptionValue) + '\n' +
                'ts_project: ' + JSON.stringify(attrVal)
            )
        }
    }
    function checkRootDirExclude() {
        var rootDirAttrValue = attrs["root_dir"];
        var outDirAttrValue = attrs["out_dir"];
        var excludeOptionValue = config["exclude"];

        let rootDirNotEmpty = rootDirAttrValue !== undefined && rootDirAttrValue !== "";
        let outDirEmpty = outDirAttrValue === undefined || outDirAttrValue === "";

        if (rootDirNotEmpty && outDirEmpty && excludeOptionValue === undefined) {
            throw new Error(
                '\n\nWhen root dir is set, exclude must also be set to empty array in the tsconfig file.\n\n' +
                'For example, tsconfig.json:\n' +
                '{\n' +
                '   "exclude": []\n' +
                '}\n\n' +
                'See tickets: https://github.com/microsoft/TypeScript/issues/59036 and ' +
                'https://github.com/aspect-build/rules_ts/issues/644\n'
            )
        }
    }
    function checkDirInParent(optionName, attrName) {
        var optionVal = options[optionName]
        if (typeof optionVal !== 'string' || !optionVal) return

        // The boundary is the rule's package, not the tsconfig's directory:
        // tsconfigs may live in subfolders (e.g. pkg/config/tsconfig.json) where
        // ".." still resolves inside the package.
        var rel = path_1.relative(packageDir, path_1.resolve(configDir, optionVal))

        if (rel === '..' || rel.startsWith('../') || rel.startsWith('..\\')) {
            throw new Error(
                '\n\nThe ' +
                    optionName +
                    ' in the tsconfig resolves to "' +
                    optionVal +
                    '"' +
                    ' which is a parent of the package directory.\n\n' +
                    'This is not supported by ts_project because all output files must be within\n' +
                    'the package output directory.\n\n' +
                    'If your tsconfig is shared from a parent directory, set ' +
                    optionName +
                    ' in that\n' +
                    'tsconfig to a path at or below the package, or use the ' +
                    attrName +
                    ' attribute\n' +
                    'on ts_project to override it.\n'
            )
        }
    }
    function check_preserve_jsx() {
        var attr = 'preserve_jsx'
        // The resolved config states enum options as their string form, e.g. "preserve".
        var jsxVal = options['jsx']
        var isPreserve = jsxVal === 'preserve'
        if (isPreserve !== Boolean(attrs[attr])) {
            failures.push(
                'attribute ' +
                    attr +
                    '=' +
                    attrs[attr] +
                    ' does not match compilerOptions.jsx=' +
                    jsxVal
            )
            buildozerCmds.push(
                'set ' + attr + ' ' + (isPreserve ? 'True' : 'False')
            )
        }
    }
    function check_nocheck() {
        if (attrs.isolated_typecheck) {
            var optionVal = getTsOption('isolatedDeclarations')
            if (!optionVal) {
                failures.push(
                    'attribute isolated_typecheck=True requires compilerOptions.isolatedDeclarations=true\nSee documentation on ts_project(isolated_typecheck) for more info"'
                )
                buildozerCmds.push('set isolated_typecheck False')
            }
        }
    }
    if (options.preserveSymlinks) {
        console.error(
            'ERROR: ts_project rule ' +
                target +
                " cannot be built because the 'preserveSymlinks' option is set."
        )
        console.error(
            'This is not compatible with ts_project due to the rules_js use of symlinks.'
        )
        return 1
    }
    var impliedByComposite = function () {
        return options['composite'] === true && attrs['composite'] === true
    }
    check('allowJs', 'allow_js', function () {
        return options['checkJs'] === true
    })
    check('declarationMap', 'declaration_map')
    check('noEmit', 'no_emit')
    check('emitDeclarationOnly', 'emit_declaration_only')
    check('resolveJsonModule', 'resolve_json_module', function () {
        var moduleKind = String(options['module']).toLowerCase()
        var moduleResolution = String(options['moduleResolution']).toLowerCase()
        return (
            ['node16', 'node18', 'node20', 'nodenext', 'preserve'].indexOf(
                moduleKind
            ) !== -1 || moduleResolution === 'bundler'
        )
    })
    check('sourceMap', 'source_map')
    check('composite')
    check('declaration', undefined, impliedByComposite)
    check('incremental', undefined, impliedByComposite)
    check('tsBuildInfoFile', 'ts_build_info_file')
    // Must run before check_out_dir to win over its less specific attr-mismatch error.
    checkDirInParent('rootDir', 'root_dir')
    checkDirInParent('outDir', 'out_dir')
    check_out_dir('outDir', 'out_dir')
    check_out_dir('declarationDir', 'declaration_dir')
    check_out_dir('rootDir', 'root_dir')
    checkRootDirExclude()
    check_nocheck()
    check_preserve_jsx()
    if (failures.length > 0) {
        console.error(
            'ERROR: ts_project rule ' +
                target +
                " was configured with attributes that don't match the tsconfig"
        )
        failures.forEach(function (f) {
            return console.error(' - ' + f)
        })
        console.error('You can automatically fix this by running:')
        console.error(
            '    npx @bazel/buildozer ' +
                buildozerCmds
                    .map(function (c) {
                        return "'" + c + "'"
                    })
                    .join(' ') +
                ' ' +
                target
        )
        return 1
    }
    // We have to write an output so that Bazel needs to execute this action.
    // Make the output change whenever the attributes changed.
    require('fs').writeFileSync(
        output,
        '\n// checked attributes for ' +
            target +
            '\n// allow_js:              ' +
            attrs.allow_js +
            '\n// composite:             ' +
            attrs.composite +
            '\n// declaration:           ' +
            attrs.declaration +
            '\n// declaration_map:       ' +
            attrs.declaration_map +
            '\n// out_dir:               ' +
            attrs.out_dir +
            '\n// declaration_dir:       ' +
            attrs.declaration_dir +
            '\n// incremental:           ' +
            attrs.incremental +
            '\n// source_map:            ' +
            attrs.source_map +
            '\n// no_emit:               ' +
            attrs.no_emit +
            '\n// emit_declaration_only: ' +
            attrs.emit_declaration_only +
            '\n// ts_build_info_file:    ' +
            attrs.ts_build_info_file +
            '\n// preserve_jsx:          ' +
            attrs.preserve_jsx +
            '\n// root_dir:              ' +
            attrs.root_dir +
            '\n',
        'utf-8'
    )
    return 0
}
if (require.main === module) {
    try {
        process.exitCode = main(process.argv.slice(2))
        if (process.exitCode != 0) {
            console.error('Or to suppress this error, either:')
            console.error(
                ' - pass --norun_validations to Bazel to turn off the feature completely, or'
            )
            console.error(' - disable validation for this target by running:')
            console.error(
                "    npx @bazel/buildozer 'set validate False' " +
                    process.argv[4]
            )
        }
    } catch (e) {
        console.error(process.argv[1], e)
    }
}
