{
  description = "update-input";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      forAllSystems =
        function:
        nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ] (system: function nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: {
        default = pkgs.writeShellScriptBin "fupdate" ''
          COMMIT=""
          INPUT=""
          STAY=false

          # Parse command line args
          while [[ $# -gt 0 ]]; do
            case $1 in
              -y|--yes)
                COMMIT=true
                shift
                ;;
              -n|--no)
                COMMIT=false
                shift
                ;;
              -h|--help)
                echo "Usage: fupdate [-y|--yes] [-n|--no] [-s|--stay] {input name} [-h|--help]"
                echo "  -y, --yes    Automatically commit the lock file"
                echo "  -n, --no     Don't commit the lock file"
                echo "  -h, --help   Show this help message"
                echo "  -s, --stay   Do not update input, only re-lock"
                echo "  (no args)    Ask interactively"
                exit 0
                ;;
              -s|--stay)
                STAY=true
                shift
                ;;
              *)
                echo "Received: $1"
                INPUT=$1
                shift
                ;;
            esac
          done

          if [ $INPUT != "" ]; then
            input=$INPUT 
          else
            input=$(                                           \
              nix flake metadata --json                        \
              | ${pkgs.jq}/bin/jq -r ".locks.nodes.root.inputs | keys[]" \
              | ${pkgs.fzf}/bin/fzf)
          fi

          if [ $COMMIT != "" ]; then 
            if $COMMIT; then 
              commit="yes"
            else
              commit="nno"
            fi
          else
            commit=$(printf "yes\nno" | ${pkgs.fzf}/bin/fzf --prompt="Commit lock file? ")
          fi

          if [ "$commit" = "yes" ]; then
            nix flake update $input --commit-lock-file
          else
            nix flake update $input
          fi
        '';
      });
    };
}
