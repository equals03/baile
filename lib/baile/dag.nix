# source: https://github.com/nix-community/home-manager/blob/master/modules/lib/dag.nix
# A generalization of Nixpkgs's `strings-with-deps.nix`.
#
# The main differences from the Nixpkgs version are
#
#  - not specific to strings, i.e., any payload is OK,
#
#  - the addition of the function `entryBefore` indicating a "wanted
#    by" relationship.
{
  lib,
  baile,
  ...
}: let
  inherit (builtins) isAttrs attrValues attrNames elem toString;
in {
  dag = {
    empty = {};

    isEntry = e: e ? data && e ? after && e ? before;
    isDag = dag: isAttrs dag && lib.all baile.dag.isEntry (attrValues dag);

    # Takes an attribute set containing entries built by entryAnywhere,
    # entryAfter, and entryBefore to a topologically sorted list of
    # entries.
    #
    # Internally this function uses the `toposort` function in
    # `<nixpkgs/lib/lists.nix>` and its value is accordingly.
    #
    # Specifically, the result on success is
    #
    #    { result = [ { name = ?; data = ?; } … ] }
    #
    # For example
    #
    #    nix-repl> topoSort {
    #                a = entryAnywhere "1";
    #                b = entryAfter [ "a" "c" ] "2";
    #                c = entryBefore [ "d" ] "3";
    #                d = entryBefore [ "e" ] "4";
    #                e = entryAnywhere "5";
    #              } == {
    #                result = [
    #                  { data = "1"; name = "a"; }
    #                  { data = "3"; name = "c"; }
    #                  { data = "2"; name = "b"; }
    #                  { data = "4"; name = "d"; }
    #                  { data = "5"; name = "e"; }
    #                ];
    #              }
    #    true
    #
    # And the result on error is
    #
    #    {
    #      cycle = [ { after = ?; name = ?; data = ? } … ];
    #      loops = [ { after = ?; name = ?; data = ? } … ];
    #    }
    #
    # For example
    #
    #    nix-repl> topoSort {
    #                a = entryAnywhere "1";
    #                b = entryAfter [ "a" "c" ] "2";
    #                c = entryAfter [ "d" ] "3";
    #                d = entryAfter [ "b" ] "4";
    #                e = entryAnywhere "5";
    #              } == {
    #                cycle = [
    #                  { after = [ "a" "c" ]; data = "2"; name = "b"; }
    #                  { after = [ "d" ]; data = "3"; name = "c"; }
    #                  { after = [ "b" ]; data = "4"; name = "d"; }
    #                ];
    #                loops = [
    #                  { after = [ "a" "c" ]; data = "2"; name = "b"; }
    #                ];
    #              }
    #    true
    topoSort = dag: let
      dagBefore = dag: name: attrNames (lib.filterAttrs (_n: v: elem name v.before) dag);
      normalizedDag =
        lib.mapAttrs (n: v: {
          name = n;
          inherit (v) data;
          after = v.after ++ dagBefore dag n;
        })
        dag;
      before = a: b: elem a.name b.after;
      sorted = lib.toposort before (attrValues normalizedDag);
    in
      if sorted ? result
      then {
        result = map (v: {inherit (v) name data after;}) sorted.result;
      }
      else sorted;

    # Applies a function to each element of the given DAG.
    map = f: lib.mapAttrs (n: v: v // {data = f n v.data;});

    entryBetween = before: after: data: {inherit data before after;};

    # Create a DAG entry with no particular dependency information.
    entryAnywhere = baile.dag.entryBetween [] [];

    entryAfter = baile.dag.entryBetween [];
    entryBefore = before: baile.dag.entryBetween before [];

    # Given a list of entries, this function places them in order within the DAG.
    # Each entry is labeled "${tag}-${entry index}" and other DAG entries can be
    # added with 'before' or 'after' referring these indexed entries.
    #
    # The entries as a whole can be given a relation to other DAG nodes. All
    # generated nodes are then placed before or after those dependencies.
    entriesBetween = tag: let
      go = i: before: after: entries: let
        name = "${tag}-${toString i}";
      in
        if entries == []
        then baile.dag.empty
        else if lib.length entries == 1
        then {
          "${name}" = baile.dag.entryBetween before after (lib.head entries);
        }
        else
          {
            "${name}" = baile.dag.entryAfter after (lib.head entries);
          }
          // go (i + 1) before [name] (lib.tail entries);
    in
      go 0;

    entriesAnywhere = tag: baile.dag.entriesBetween tag [] [];
    entriesAfter = tag: baile.dag.entriesBetween tag [];
    entriesBefore = tag: before: baile.dag.entriesBetween tag before [];
  };
}
