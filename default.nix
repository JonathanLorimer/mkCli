{
  lib,
  writeShellScriptBin,
}: let
  colors = let
    mkAnsiColorFn = code: text: "\\033[${code}m${text}\\033[0m";
  in {
    black = mkAnsiColorFn "0;30";
    red = mkAnsiColorFn "0;31";
    green = mkAnsiColorFn "0;32";
    yellow = mkAnsiColorFn "0;33";
    blue = mkAnsiColorFn "0;34";
    purple = mkAnsiColorFn "0;35";
    cyan = mkAnsiColorFn "0;36";
    white = mkAnsiColorFn "0;37";

    boldBlack = mkAnsiColorFn "1;30";
    boldRed = mkAnsiColorFn "1;31";
    boldGreen = mkAnsiColorFn "1;32";
    boldYellow = mkAnsiColorFn "1;33";
    boldBlue = mkAnsiColorFn "1;34";
    boldPurple = mkAnsiColorFn "1;35";
    boldCyan = mkAnsiColorFn "1;36";
    boldWhite = mkAnsiColorFn "1;37";
  };

  commandColors = [
    colors.red
    colors.green
    colors.yellow
    colors.blue
    colors.purple
    colors.cyan
    colors.white
  ];

  indent = map (str: "  " + str);

  concatMapAttrsToList = fn: attrs:
    lib.concatLists (lib.mapAttrsToList fn attrs);

  exactWidthString = width: str:
    lib.fixedWidthString width " " (builtins.substring 0 width str);

  mkAllHandler = prefix: options: let
    getCommands = prefix':
      concatMapAttrsToList (
        key: value:
          if builtins.isString value
          then [
            {
              cmd = value;
              prefix = "${prefix'} ${key}";
            }
          ]
          else getCommands "${prefix'} ${key}" value
      );
    color = index: builtins.elemAt commandColors (lib.mod index (builtins.length commandColors));
    prefixStr = pos: prefix:
      ((color pos) (exactWidthString 20 prefix)) + (colors.boldWhite " │ ");
    allCommands =
      lib.imap0
      (pos: {
        cmd,
        prefix,
      }: let
        doPrefix = "sed \"s/^/$(printf \"${prefixStr pos prefix}\")/\"";
      in [
        "${cmd} 2>&1 | ${doPrefix} &"
        "pids+=($!)"
      ])
      (getCommands prefix options);
  in
    (lib.concatLists allCommands) ++ ["for pid in \${pids[*]}; do wait $pid; done"];

  mkHelpOptions = option: value:
    if builtins.isString value
    then ["${colors.boldWhite "${option}:"} ${value}"]
    else
      [option]
      ++ (
        indent (concatMapAttrsToList mkHelpOptions value)
      );

  mkHelp = prefix: options:
    map (str: "echo -e '${str}'") (
      [
        "Usage: ${prefix} <option>"
        ""
        "Possible options:"
      ]
      ++ (indent (concatMapAttrsToList mkHelpOptions options))
    );

  mkOptionHandler = prefix: key: value:
    if builtins.isString value
    then ["${key}) ${value} ;;"]
    else
      ["${key})"]
      ++ (indent ((mkOptions "${prefix} ${key}" value) ++ [";;"]));

  mkOptions = prefix: options: let
    options' = builtins.removeAttrs options ["_noAll"];
  in
    [
      "option=\"$1\""
      "shift || true"
      "case \"$option\" in"
    ]
    ++ (indent (
      (concatMapAttrsToList (mkOptionHandler prefix) options')
      ++ (
        if !options._noAll or false
        then ["all|'')"] ++ (indent (mkAllHandler prefix options' ++ [";;"]))
        else []
      )
      ++ ["*)"]
      ++ (indent ((mkHelp prefix options') ++ [";;"]))
    ))
    ++ ["esac"];
in
  name: options:
    writeShellScriptBin name ''
      set -e

      ${lib.concatStringsSep "\n" (mkOptions name options)}
    ''
