'use strict'
exports.__esModule = true
var path_1 = require('path')
var ts = require('typescript')
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
function main(_a) {
    var _b
    var tsconfigPath = _a[0],
        output = _a[1],
        target = _a[2],
        packageDir = _a[3],
        attrsStr = _a[4]
    // The Bazel ts_project attributes were json-encoded
    // (on Windows the quotes seem to be quoted wrong, so replace backslash with quotes :shrug:)
    var attrs = JSON.parse(attrsStr.replace(/\\/g, '"'))
    // Parse your typescript settings from the tsconfig
    // This will understand the "extends" semantics.
    var _c = ts.readConfigFile(tsconfigPath, ts.sys.readFile),
        config = _c.config,
        error = _c.error
    if (error)
        throw new Error(
            tsconfigPath + ':' + ts.formatDiagnostic(error, diagnosticsHost)
        )
    var _d = ts.parseJsonConfigFileContent(
            config,
            ts.sys,
            path_1.dirname(tsconfigPath)
        ),
        errors = _d.errors,
        options = _d.options
    // We don't pass the srcs to this action, so it can't know if the program has the right sources.
    // Diagnostics look like
    // error TS18002: The 'files' list in config file 'tsconfig.json' is empty.
    // error TS18003: No inputs were found in config file 'tsconfig.json'. Specified 'include'...
    var fatalErrors = errors.filter(function (e) {
        return e.code !== 18002 && e.code !== 18003
    })
    if (fatalErrors.length > 0)
        throw new Error(
            tsconfigPath +
                ':' +
                ts.formatDiagnostics(fatalErrors, diagnosticsHost)
        )
    var failures = []
    var buildozerCmds = []
    function getTsOption(option) {
        if (typeof options[option] === 'string') {
            // Currently the only string-typed options are filepaths.
            // TypeScript will resolve these to a project path
            // so when echoing that back to the user, we need to reverse that resolution.
            return path_1.relative(packageDir, options[option])
        }
        return options[option]
    }
    function check(option, attr, failOnlyIfAttrIsUndefined = false) {
        attr = attr || option
        // treat compilerOptions undefined as false
        var optionVal = getTsOption(option)
        var attributeIsFalsy = attrs[attr] === false || attrs[attr] === '';
        var attributeIsFalsyOrUndefined = attributeIsFalsy || attrs[attr] === undefined
        var shouldFailBecauseAttributeIsFalsyAndOptionIsDefined =
            failOnlyIfAttrIsUndefined && attributeIsFalsyOrUndefined && optionVal !== undefined
        var parametersMatch = optionVal === attrs[attr] ||
            (optionVal === undefined && attributeIsFalsy);
        var checkPassed =
            parametersMatch ||
            !shouldFailBecauseAttributeIsFalsyAndOptionIsDefined
        if (!checkPassed) {
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
    var jsxEmit =
        ((_b = {}),
        (_b[ts.JsxEmit.None] = 'none'),
        (_b[ts.JsxEmit.Preserve] = 'preserve'),
        (_b[ts.JsxEmit.React] = 'react'),
        (_b[ts.JsxEmit.ReactNative] = 'react-native'),
        (_b[ts.JsxEmit.ReactJSX] = 'react-jsx'),
        (_b[ts.JsxEmit.ReactJSXDev] = 'react-jsx-dev'),
        _b)
    function check_preserve_jsx() {
        var attr = 'preserve_jsx'
        var jsxVal = options['jsx']
        if ((jsxVal === ts.JsxEmit.Preserve) !== Boolean(attrs[attr])) {
            failures.push(
                'attribute ' +
                    attr +
                    '=' +
                    attrs[attr] +
                    ' does not match compilerOptions.jsx=' +
                    jsxEmit[jsxVal]
            )
            buildozerCmds.push(
                'set ' +
                    attr +
                    ' ' +
                    (jsxVal === ts.JsxEmit.Preserve ? 'True' : 'False')
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
    check('allowJs', 'allow_js')
    check('declarationMap', 'declaration_map')
    check('noEmit', 'no_emit')
    check('emitDeclarationOnly', 'emit_declaration_only')
    check('resolveJsonModule', 'resolve_json_module')
    check('sourceMap', 'source_map')
    check('composite')
    check('declaration')
    check('incremental')
    check('tsBuildInfoFile', 'ts_build_info_file')
    check('outDir', 'out_dir', true)
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
