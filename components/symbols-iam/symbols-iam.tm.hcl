# Emits the symbol-library wiring for a stack:
#   language { experiments = [symbol_libraries] }   # gate the experiment
#   symbols  "iam" { source = "<../..>/lib/iam" }   # bind the shared library
#
# The library lives once at the project root (/lib/iam); `source` is a local
# path relative to the stack, so we compute the "../" prefix from the stack's
# depth. symbol_libraries is a bare experiment identifier and the source path
# must survive verbatim, so both are emitted via tm_hcl_expression / literals
# rather than Terramate-evaluated references.
generate_hcl "_tmgen-symbols.tf" {
  lets {
    # Count real path segments (robust to a leading/trailing slash).
    depth = tm_length([for s in tm_split("/", terramate.stack.path.relative) : s if s != ""])
    up    = tm_join("", [for _ in tm_range(0, let.depth) : "../"])
    src   = "${let.up}${component.input.lib_path.value}"
  }
  content {
    language {
      experiments = tm_hcl_expression("[symbol_libraries]")
    }
    symbols "iam" {
      source = let.src
    }
  }
}
