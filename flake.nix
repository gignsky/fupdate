{
  description = "fupdate, or, Flake Update -- Tastefully Aquired From Vimjoyer & Refined";

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
          INPUT=false
          SELECTED_INPUT=""
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
                echo "STAY SELECTED: Flake Lock Update -- No Input Update"
                shift
                ;;
              *)
                echo "Received: $1"
                SELECTED_INPUT=$1
                INPUT=true
                shift
                ;;
            esac
          done

          if $INPUT; then
              input=$SELECTED_INPUT 
          else
            if ! $STAY; then 
              # echo "No input specified, please select an input to update:"
              input=$(                                           \
                nix flake metadata --json                        \
                | ${pkgs.jq}/bin/jq -r ".locks.nodes.root.inputs | keys[]" \
                | ${pkgs.fzf}/bin/fzf)
              # echo "You selected: $input"
            fi 
          fi

          while [[ -z $COMMIT ]]; do
            answer=$(printf "yes\nno" | ${pkgs.fzf}/bin/fzf --prompt="Commit lock file? ")
            if [ "$answer" == "yes" ]; then
              COMMIT=true
            else 
              COMMIT=false
            fi
          done

          if $COMMIT; then 
            commit="yes"
            echo "Lock File WILL be COMMITTED."
          else
            commit="nno"
            echo "NO Lock File will be committed."
          fi

          if $STAY; then
            echo "Updating Lock File"
            if [ "$commit" == "yes" ]; then 
              nix flake lock --commit-lock-file
            else
              nix flake lock
            fi
            echo "Lock File Updated!"
          else
            echo "Updating input: $input - You answered: '$commit' to Committing."
            if [ "$commit" = "yes" ]; then
              nix flake update $input --commit-lock-file
            else
              nix flake update $input
            fi
          fi
        '';
      });
    };
}
