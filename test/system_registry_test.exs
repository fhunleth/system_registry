defmodule SystemRegistryTest do
  use ExUnit.Case, async: true
  doctest SystemRegistry

  alias SystemRegistry, as: SR
  alias SystemRegistry.Node

  setup ctx do
    %{root: ctx.test}
  end

  test "maps are transformed into composed transactions", %{root: root} do
    t =
      SR.transaction()
      |> SR.update([root], %{b: 1, c: 2})

    parent = %Node{parent: [], node: [root], from: nil, key: root}
    leaf_b = %Node{parent: [root], node: [root, :b], from: self(), key: :b}
    leaf_c = %Node{parent: [root], node: [root, :c], from: self(), key: :c}

    assert MapSet.member?(t.update_nodes, parent)
    assert MapSet.member?(t.update_nodes, leaf_b)
    assert MapSet.member?(t.update_nodes, leaf_c)

    assert t.updates == %{root => %{b: 1, c: 2}}
  end

  test "local transaction commit", %{root: root} do
    update = %{root => %{a: 1}}
    SR.update([], update)
    assert ^update = SR.match(self(), update)

    SR.delete([root, :a])
    assert %{} == SR.match(self(), :_)
  end

  test "match specs", %{root: root} do
    update = %{root => %{a: 1}}
    SR.update([], update)
    assert ^update = SR.match(self(), update)
    assert %{} == SR.match(self(), %{blah: %{}})
  end

  test "can delete all nodes for a process", %{root: root} do
    SR.transaction
    |> SR.update([root, :a, :b], 1)
    |> SR.update([root, :a, :c], 1)
    |> SR.commit

    assert %{^root => %{a: %{b: 1, c: 1}}} = SR.match(self(), %{root => %{}})
    SR.delete_all()
    value = SR.match(self(), :_)
    assert Map.get(value, root) == nil
  end

  test "delete nodes", %{root: root} do
    SR.update([root, :a], 1)
    SR.delete([root, :a])
    assert SR.match(self(), %{root => :_}) == %{}

    SR.update([root, :a, :b], 1)
    SR.delete([root, :a])
    assert SR.match(self(), %{root => :_}) == %{}
  end

  test "bindings are removed when owner deletes", %{root: root} do
    scope = [root, :a]
    # task = Task.async(fn ->
    #   self = self()
    #   SR.update(scope, 1)
    #   assert %{from: ^self} = Node.binding(scope)
    #   SR.delete(scope)
    # end)
    # Task.await(task)
    self = self()
    assert Node.binding({self, scope}) == nil
    assert {:ok, _} = SR.update([root, :a], 1)
    assert %{from: ^self} = Node.binding({self, scope})
  end

  test "nodes can be deleted from a internal node", %{root: root} do
    leaf_scope = [root, :a, :b]
    inter_scope = [root, :a]

    SR.update(leaf_scope, 1)

    self = self()
    assert %{from: ^self} = Node.binding({self, leaf_scope})
    assert %{from: nil} = Node.binding({self, inter_scope})
    SR.delete(inter_scope)
    assert Node.binding({self, leaf_scope}) == nil
    assert Node.binding({self, inter_scope}) == nil
  end

end
