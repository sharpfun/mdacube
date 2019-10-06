defmodule MDACube do
  @moduledoc """
  Experimental Multi-Dimensional Attribute Cube.
  Allows to set attributes by coordinates. Use partial coordinates, so any
  unspecified dimension's member attribute will have the same value.
  Possible useful for: ranking by multi-attributes.
  Provides great visibility.

  Example:
  TODO
  """

  defstruct [
    dimensions: %{}, # %{dimension1: %MapSet{} = items1}
    attributes: %{}, # %{attribute1: %{CoordinatesMap => value}}
  ]

  def new(), do: %__MODULE__{}

  @doc """
  Set attribute by coordinates (can be partial), attribute label and value
  """
  def set(%__MODULE__{} = cube, coordinates, attribute_label, value)
  when is_map(coordinates) do
    facts = cube.attributes
    |> Map.get(attribute_label, %{})
    |> Map.put(coordinates, value)
    attributes = Map.put(cube.attributes, attribute_label, facts)

    dimensions = for dimension <- coordinates |> Map.keys do
      members = cube.dimensions
      |> Map.get(dimension, %MapSet{})
      |> MapSet.put(coordinates[dimension])
      {dimension, members}
    end
    |> Enum.into(cube.dimensions)

    %{cube | attributes: attributes, dimensions: dimensions}
  end

  @doc """
  Returns cells count
  """
  def count(%__MODULE__{dimensions: dimensions} = _cube)
  when map_size(dimensions) == 0, do: 0
  def count(%__MODULE__{} = cube) do
    cube.dimensions
    |> Map.values
    |> Enum.reduce(1, fn x, acc -> MapSet.size(x) * acc end)
  end
end

defimpl Enumerable, for: MDACube do
  @moduledoc """
  Enumerable implementation for MDACube, Enum module is fully supported.
  """

  defstruct [
    index: 0,
    count: 0,
    dimensions: [],
    attributes: [],
    cube: nil
  ]

  @doc """
  Enumerable reduce implementation
  """
  def reduce(%MDACube{} = cube, action, fun) do
    reduce(get_iterable(cube), action, fun)
  end
  def reduce(_iterable, {:halt, acc}, _fun), do: {:halted, acc}
  def reduce(iterable, {:suspend, acc}, fun), do:
    {:suspended, acc, &reduce(iterable, &1, fun)}
  def reduce(%__MODULE__{index: index, count: index}, {:cont, acc}, _fun), do:
    {:done, acc}
  def reduce(%__MODULE__{index: index} = iterable, {:cont, acc}, fun) do
    coordinates = get_row_coordinates(iterable, index)
    attributes = get_row(iterable, coordinates)
    data = %{coordinates: coordinates, attributes: attributes}
    reduce(%{iterable | index: index+1}, fun.(data, acc), fun)
  end

  def count(cube), do: {:ok, MDACube.count(cube)}

  @doc """
  Enumerable member? implementation
  """
  def member?(cube, x), do: {:ok, get_row(cube, x.coordinates) == x.attributes}

  @doc """
  Enumerable slice implementation
  """
  def slice(cube) do
    reducer = fn x, acc -> {:cont, [x | acc]} end
    slicer = fn index, length ->
      iterable = %{get_iterable(cube) | index: index, count: index+length}
      iterable
      |> reduce({:cont, []}, reducer)
      |> elem(1)
      |> :lists.reverse()
    end
    {:ok, MDACube.count(cube), slicer}
  end

  defp get(coordinates, attribute) when is_map(coordinates) do
    attribute_facts = attribute.facts
    coordinates = attribute.subsets
    |> Enum.map(&(Map.take(coordinates, &1)))
    |> Enum.find(&(Map.has_key?(attribute_facts, &1)))
    coordinates && attribute_facts[coordinates]
  end

  defp get_row(%__MODULE__{} = iterable, coordinates) do
    iterable.attributes
    |> Enum.reduce(%{}, fn attribute, acc ->
      Map.put(acc, attribute.label, get(coordinates, attribute))
    end)
  end

  defp get_row_coordinates(iterable, index) do
    members_indexes = get_members_indexes(iterable, index)
    Enum.zip(iterable.dimensions, members_indexes)
    |> Enum.reduce(%{}, fn {item, member_index}, acc ->
      Map.put(acc, item.dimension, Enum.at(item.members, member_index))
    end)
  end

  defp get_members_indexes(iterable, index) do
    iterable.dimensions
    |> Enum.reverse
    |> do_get_members_indexes(index)
    |> Enum.reverse
  end

  defp do_get_members_indexes([], 0), do: []
  defp do_get_members_indexes([%{members_count: members_count} | tail], index) do
    member_index = rem(index, members_count)
    rest_index = div(index, members_count)
    [member_index | do_get_members_indexes(tail, rest_index)]
  end

  defp get_iterable(cube) do
    %__MODULE__{
      index: 0,
      count: MDACube.count(cube),
      dimensions: dimensions_ordered(cube),
      attributes: cube.attributes |> aggregate_attributes,
      cube: cube}
  end

  defp aggregate_attributes(attributes) do
    attributes
    |> Enum.map(fn {label, facts} ->
      subsets = facts
      |> Enum.reduce(MapSet.new(), fn {coordinates, _value}, acc ->
        MapSet.union(acc, [coordinates |> Map.keys |> Enum.sort] |> MapSet.new)
      end)
      |> MapSet.to_list
      %{label: label, subsets: subsets, facts: facts}
    end)
  end

  defp dimensions_ordered(%MDACube{} = cube) do
    for dimension <- cube.dimensions |> Map.keys |> Enum.sort do
      members = cube.dimensions
      |> Map.get(dimension)
      |> MapSet.to_list
      |> Enum.sort

      %{dimension: dimension,
        members: members,
        members_count: length(members)}
    end
  end
end

