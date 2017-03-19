defmodule FunWithFlags do
  @moduledoc """
  FunWithFlags, the Elixir feature flag library.

  This module provides the public interface to the library and its API is
  made of three simple methods to enable, disable and query feature flags.

  In their simplest form, flags can be toggled on and off globally.

  More advanced rules or "gates" are available, and they can be set and queried
  for any term that implements these protocols:

  * The `FunWithFlags.Actor` protocol can be
  implemented for types and structs that should have specific rules. For
  example, in web applications it's common to use a `%User{}` struct or
  equivalent as an actor, or perhaps the current country of the request.

  * The `FunWithFlags.Group` protocol can be
  implemented for types and structs that should belong to groups for which
  one wants to enable and disable some flags. For example, one could implement
  the protocol for a `%User{}` struct to identify administrators.


  See the [Usage](/fun_with_flags/readme.html#usage) notes for a more detailed
  explanation.
  """

  alias FunWithFlags.{Flag, Gate}

  @store FunWithFlags.Config.store_module

  @type options :: Keyword.t



  @doc """
  Checks if a flag is enabled.

  It can be invoked with just the flag name, as an atom,
  to check the general staus of a flag (i.e. the boolean gate).

  ## Options

  * `:for` - used to provide a term for which the flag could
  have a specific value. The passed term should implement the
  `Actor` or `Group` protocol, or both.

  ## Examples

  This example relies on the [reference implementation](https://github.com/tompave/fun_with_flags/blob/master/test/support/test_user.ex)
  used in the tests.

      iex> alias FunWithFlags.TestUser, as: User
      iex> harry = %User{id: 1, name: "Harry Potter", groups: [:wizards, :gryffindor]}
      iex> FunWithFlags.disable(:elder_wand)
      iex> FunWithFlags.enable(:elder_wand, for_actor: harry)
      iex> FunWithFlags.enabled?(:elder_wand)
      false
      iex> FunWithFlags.enabled?(:elder_wand, for: harry)
      true
      iex> voldemort = %User{id: 7, name: "Tom Riddle", groups: [:wizards, :slytherin]}
      iex> FunWithFlags.enabled?(:elder_wand, for: voldemort)
      false
      iex> filch = %User{id: 88, name: "Argus Filch", groups: [:staff]}
      iex> FunWithFlags.enable(:magic_wands, for_group: :wizards)
      iex> FunWithFlags.enabled?(:magic_wands, for: harry)
      true
      iex> FunWithFlags.enabled?(:magic_wands, for: voldemort)
      true
      iex> FunWithFlags.enabled?(:magic_wands, for: filch)
      false

  """
  @spec enabled?(atom, options) :: boolean

  def enabled?(flag_name, options \\ [])


  def enabled?(flag_name, []) when is_atom(flag_name) do
    case @store.lookup(flag_name) do
      {:ok, flag} -> Flag.enabled?(flag)
      _           -> false
    end
  end

  def enabled?(flag_name, [for: nil]) do
    enabled?(flag_name)
  end

  def enabled?(flag_name, [for: item]) when is_atom(flag_name) do
    case @store.lookup(flag_name) do
      {:ok, flag} -> Flag.enabled?(flag, for: item)
      _           -> false
    end
  end


  @doc """
  Enables a feature flag.

  ## Options

  * `:for_actor` - used to enable the flag for a specific term only.
  The value can be any term that implements the `Actor` protocol.
  * `:for_group` - used to enable the flag for a specific group only.
  The value should be an atom.

  ## Examples

  ### Enable globally

      iex> FunWithFlags.enabled?(:super_shrink_ray)
      false
      iex> FunWithFlags.enable(:super_shrink_ray)
      {:ok, true}
      iex> FunWithFlags.enabled?(:super_shrink_ray)
      true

  ### Enable for an actor

      iex> FunWithFlags.disable(:warp_drive)
      {:ok, false}
      iex> FunWithFlags.enable(:warp_drive, for_actor: "Scotty")
      {:ok, true}
      iex> FunWithFlags.enabled?(:warp_drive)
      false
      iex> FunWithFlags.enabled?(:warp_drive, for: "Scotty")
      true

  ### Enable for a group

  This example relies on the [reference implementation](https://github.com/tompave/fun_with_flags/blob/master/test/support/test_user.ex)
  used in the tests.
      
      iex> alias FunWithFlags.TestUser, as: User
      iex> marty = %User{name: "Marty McFly", groups: [:students, :time_travelers]}
      iex> doc = %User{name: "Emmet Brown", groups: [:scientists, :time_travelers]}
      iex> buford = %User{name: "Buford Tannen", groups: [:gunmen, :bandits]}
      iex> FunWithFlags.enable(:delorean, for_group: :time_travelers)
      {:ok, true}
      iex> FunWithFlags.enabled?(:delorean)
      false
      iex> FunWithFlags.enabled?(:delorean, for: buford)
      false
      iex> FunWithFlags.enabled?(:delorean, for: marty)
      true
      iex> FunWithFlags.enabled?(:delorean, for: doc)
      true

  """
  @spec enable(atom, options) :: {:ok, true}
  def enable(flag_name, options \\ [])

  def enable(flag_name, []) when is_atom(flag_name) do
    {:ok, flag} = @store.put(flag_name, Gate.new(:boolean, true))
    verify(flag)
  end

  def enable(flag_name, [for_actor: nil]) do
    enable(flag_name)
  end

  def enable(flag_name, [for_actor: actor]) when is_atom(flag_name) do
    gate = Gate.new(:actor, actor, true)
    {:ok, flag} = @store.put(flag_name, gate)
    verify(flag, for: actor)
  end


  def enable(flag_name, [for_group: nil]) do
    enable(flag_name)
  end

  def enable(flag_name, [for_group: group_name]) when is_atom(flag_name) do
    gate = Gate.new(:group, group_name, true)
    {:ok, _flag} = @store.put(flag_name, gate)
    {:ok, true}
  end



  @doc """
  Disables a feature flag.

  ## Options

  * `:for_actor` - used to disable the flag for a specific term only.
  The value can be any term that implements the `Actor` protocol.
  * `:for_group` - used to disable the flag for a specific group only.
  The value should be an atom.

  ## Examples

  ### Disable globally

      iex> FunWithFlags.enable(:random_koala_gifs)
      iex> FunWithFlags.enabled?(:random_koala_gifs)
      true
      iex> FunWithFlags.disable(:random_koala_gifs)
      {:ok, false}
      iex> FunWithFlags.enabled?(:random_koala_gifs)
      false


  ## Disable for an actor

      iex> FunWithFlags.enable(:spider_sense)
      {:ok, true}
      iex> villain = %{name: "Venom"}
      iex> FunWithFlags.disable(:spider_sense, for_actor: villain)
      {:ok, false}
      iex> FunWithFlags.enabled?(:spider_sense)
      true
      iex> FunWithFlags.enabled?(:spider_sense, for: villain)
      false

  ### Disable for a group

  This example relies on the [reference implementation](https://github.com/tompave/fun_with_flags/blob/master/test/support/test_user.ex)
  used in the tests.
      
      iex> alias FunWithFlags.TestUser, as: User
      iex> harry = %User{name: "Harry Potter", groups: [:wizards, :gryffindor]}
      iex> dudley = %User{name: "Dudley Dursley", groups: [:muggles]}
      iex> FunWithFlags.enable(:hogwarts)
      {:ok, true}
      iex> FunWithFlags.disable(:hogwarts, for_group: :muggles)
      {:ok, false}
      iex> FunWithFlags.enabled?(:hogwarts)
      true
      iex> FunWithFlags.enabled?(:hogwarts, for: harry)
      true
      iex> FunWithFlags.enabled?(:hogwarts, for: dudley)
      false

  """
  @spec disable(atom, options) :: {:ok, false}
  def disable(flag_name, options \\ [])

  def disable(flag_name, []) when is_atom(flag_name) do
    {:ok, flag} = @store.put(flag_name, Gate.new(:boolean, false))
    verify(flag)
  end

  def disable(flag_name, [for_actor: nil]) do
    disable(flag_name)
  end

  def disable(flag_name, [for_actor: actor]) when is_atom(flag_name) do
    gate = Gate.new(:actor, actor, false)
    {:ok, flag} = @store.put(flag_name, gate)
    verify(flag, for: actor)
  end

  def disable(flag_name, [for_group: nil]) do
    disable(flag_name)
  end

  def disable(flag_name, [for_group: group_name]) when is_atom(flag_name) do
    gate = Gate.new(:group, group_name, false)
    {:ok, _flag} = @store.put(flag_name, gate)
    {:ok, false}
  end


  defp verify(flag) do
    {:ok, Flag.enabled?(flag)}
  end
  defp verify(flag, [for: data]) do
    {:ok, Flag.enabled?(flag, for: data)}
  end
end
