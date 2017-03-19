defmodule FunWithFlagsTest do
  use ExUnit.Case, async: false
  import FunWithFlags.TestUtils
  import Mock

  doctest FunWithFlags

  setup_all do
    on_exit(__MODULE__, fn() -> clear_redis_test_db() end)
    :ok
  end

  describe "enabled?(name)" do
    test "it returns false for non existing feature flags" do
      flag_name = unique_atom()
      assert false == FunWithFlags.enabled?(flag_name)
    end

    test "it returns false for a disabled feature flag" do
      flag_name = unique_atom()
      FunWithFlags.disable(flag_name)
      assert false == FunWithFlags.enabled?(flag_name)
    end

    test "it returns true for an enabled feature flag" do
      flag_name = unique_atom()
      FunWithFlags.enable(flag_name)
      assert true == FunWithFlags.enabled?(flag_name)
    end

    test "if the store returns anything other than {:ok, _}, it returns false" do
      name = unique_atom()
      {:ok, true} = FunWithFlags.enable(name)
      assert true == FunWithFlags.enabled?(name)

      store = FunWithFlags.Config.store_module

      with_mock(store, [], lookup: fn(^name) -> {:error, "mocked"} end) do
        assert false == FunWithFlags.enabled?(name)
      end
    end


    test "if the store raises an error, it lets it bubble up" do
      name = unique_atom()
      store = FunWithFlags.Config.store_module

      with_mock(store, [], lookup: fn(^name) -> raise(RuntimeError, "mocked exception") end) do
        assert_raise RuntimeError, "mocked exception", fn() ->
          FunWithFlags.enabled?(name)
        end
      end
    end
  end


  describe "enabled?(name, for: item)" do
    setup do
      scrooge = %FunWithFlags.TestUser{id: 1, email: "scrooge@mcduck.pdp", groups: [:ducks, :billionaires]}
      donald = %FunWithFlags.TestUser{id: 2, email: "donald@duck.db", groups: [:ducks, :super_heroes]}
      {:ok, scrooge: scrooge, donald: donald, flag_name: unique_atom()}
    end

    test "it returns false for non existing feature flags", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      refute FunWithFlags.enabled?(flag_name)
      refute FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)
    end


    # actors ------------------------------------

    test "it returns true for an enabled actor even though the flag doesn't have a general value,
          while other actors fallback to the default (false)", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      FunWithFlags.enable(flag_name, for_actor: scrooge)
      refute FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)
    end

    test "it returns true for an enabled actor even though the flag is disabled, while other
          actors fallback to the boolean gate (false)", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      FunWithFlags.enable(flag_name, for_actor: scrooge)
      FunWithFlags.disable(flag_name)
      refute FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)
    end

    test "it returns false for a disabled actor even though the flag is enabled, while other
          actors fallback to the boolean gate (true)", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      FunWithFlags.disable(flag_name, for_actor: donald)
      FunWithFlags.enable(flag_name)
      assert FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)
    end

    test "more than one actor can be enabled", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      FunWithFlags.disable(flag_name)
      FunWithFlags.enable(flag_name, for_actor: scrooge)
      FunWithFlags.enable(flag_name, for_actor: donald)
      refute FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      assert FunWithFlags.enabled?(flag_name, for: donald)
    end

    test "more than one actor can be disabled", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      FunWithFlags.enable(flag_name)
      FunWithFlags.disable(flag_name, for_actor: scrooge)
      FunWithFlags.disable(flag_name, for_actor: donald)
      assert FunWithFlags.enabled?(flag_name)
      refute FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)
    end

    # groups ------------------------------------

    test "it returns true for an item that belongs to an enabled group even though the flag doesn't have a general value,
          while other items fallback to the default (false)", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      FunWithFlags.enable(flag_name, for_group: :billionaires)
      refute FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)
    end

    test "it returns true for an item that belongs to an enabled group even though the flag is disabled, while other
          items fallback to the boolean gate (false)", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      FunWithFlags.enable(flag_name, for_group: :billionaires)
      FunWithFlags.disable(flag_name)
      refute FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)
    end

    test "it returns false for an item that belongs to a disabled group even though the flag is enabled, while other
          items fallback to the boolean gate (true)", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      FunWithFlags.disable(flag_name, for_group: :super_heroes)
      FunWithFlags.enable(flag_name)
      assert FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)
    end

    test "more than one group can be enabled", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      FunWithFlags.disable(flag_name)
      FunWithFlags.enable(flag_name, for_group: :super_heroes)
      FunWithFlags.enable(flag_name, for_group: :villains)
      evron = %FunWithFlags.TestUser{name: "Evron", groups: [:aliens, :villains]}
      batman = %FunWithFlags.TestUser{name: "Batman", groups: [:humans, :super_heroes]}


      refute FunWithFlags.enabled?(flag_name)
      refute FunWithFlags.enabled?(flag_name, for: scrooge)
      assert FunWithFlags.enabled?(flag_name, for: donald)
      assert FunWithFlags.enabled?(flag_name, for: evron)
      assert FunWithFlags.enabled?(flag_name, for: batman)
    end

    test "more than one group can be disabled", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      FunWithFlags.enable(flag_name)
      FunWithFlags.disable(flag_name, for_group: :super_heroes)
      FunWithFlags.disable(flag_name, for_group: :villains)
      evron = %FunWithFlags.TestUser{name: "Evron", groups: [:aliens, :villains]}
      batman = %FunWithFlags.TestUser{name: "Batman", groups: [:humans, :super_heroes]}


      assert FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)
      refute FunWithFlags.enabled?(flag_name, for: evron)
      refute FunWithFlags.enabled?(flag_name, for: batman)
    end
  end


  describe "enabling and disabling flags" do
    setup do
      scrooge = %FunWithFlags.TestUser{id: 1, email: "scrooge@mcduck.pdp", groups: [:ducks, :billionaires]}
      donald = %FunWithFlags.TestUser{id: 2, email: "donald@duck.db", groups: [:ducks, :super_heroes]}
      mickey = %FunWithFlags.TestUser{id: 3, email: "mickey@mouse.tp", groups: [:mice]}
      {:ok, scrooge: scrooge, donald: donald, mickey: mickey, flag_name: unique_atom()}
    end


    test "flags can be enabled and disabled with simple boolean gates", %{flag_name: flag_name} do
      refute FunWithFlags.enabled?(flag_name)

      FunWithFlags.enable(flag_name)
      assert FunWithFlags.enabled?(flag_name)

      FunWithFlags.disable(flag_name)
      refute FunWithFlags.enabled?(flag_name)
    end


    test "flags can be enabled for specific actors", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      refute FunWithFlags.enabled?(flag_name)
      refute FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)

      FunWithFlags.enable(flag_name, for_actor: scrooge)
      refute FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)

      FunWithFlags.enable(flag_name)
      assert FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      assert FunWithFlags.enabled?(flag_name, for: donald)
    end


    test "flags can be disabled for specific actors", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      refute FunWithFlags.enabled?(flag_name)
      refute FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)

      FunWithFlags.enable(flag_name)
      assert FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      assert FunWithFlags.enabled?(flag_name, for: donald)

      FunWithFlags.disable(flag_name, for_actor: donald)
      assert FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)

      FunWithFlags.disable(flag_name)
      refute FunWithFlags.enabled?(flag_name)
      refute FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)

      FunWithFlags.enable(flag_name, for_actor: scrooge)
      refute FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)
    end


    test "flags can be enabled for specific groups", %{scrooge: scrooge, donald: donald, mickey: mickey, flag_name: flag_name} do
      refute FunWithFlags.enabled?(flag_name)
      refute FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)
      refute FunWithFlags.enabled?(flag_name, for: mickey)

      FunWithFlags.enable(flag_name, for_group: :ducks)
      refute FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      assert FunWithFlags.enabled?(flag_name, for: donald)
      refute FunWithFlags.enabled?(flag_name, for: mickey)

      FunWithFlags.enable(flag_name)
      assert FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      assert FunWithFlags.enabled?(flag_name, for: donald)
      assert FunWithFlags.enabled?(flag_name, for: mickey)
    end


    test "flags can be disabled for specific groups", %{scrooge: scrooge, donald: donald, mickey: mickey, flag_name: flag_name} do
      FunWithFlags.enable(flag_name)
      assert FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: scrooge)
      assert FunWithFlags.enabled?(flag_name, for: donald)
      assert FunWithFlags.enabled?(flag_name, for: mickey)

      FunWithFlags.disable(flag_name, for_group: :ducks)
      assert FunWithFlags.enabled?(flag_name)
      refute FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)
      assert FunWithFlags.enabled?(flag_name, for: mickey)

      FunWithFlags.disable(flag_name)
      refute FunWithFlags.enabled?(flag_name)
      refute FunWithFlags.enabled?(flag_name, for: scrooge)
      refute FunWithFlags.enabled?(flag_name, for: donald)
      refute FunWithFlags.enabled?(flag_name, for: mickey)
    end


    test "enabling always returns the tuple {:ok, true} on success", %{flag_name: flag_name} do
      assert {:ok, true} = FunWithFlags.enable(flag_name)
      assert {:ok, true} = FunWithFlags.enable(flag_name)
      assert {:ok, true} = FunWithFlags.enable(flag_name, for_actor: "a string")
      assert {:ok, true} = FunWithFlags.enable(flag_name, for_group: :group_name)
    end

    test "disabling always returns the tuple {:ok, false} on success", %{flag_name: flag_name} do
      assert {:ok, false} = FunWithFlags.disable(flag_name)
      assert {:ok, false} = FunWithFlags.disable(flag_name)
      assert {:ok, false} = FunWithFlags.disable(flag_name, for_actor: "a string")
      assert {:ok, false} = FunWithFlags.disable(flag_name, for_group: :group_name)
    end
  end


  describe "gate interactions" do
    alias FunWithFlags.TestUser, as: User
    setup do
      harry = %User{id: 1, name: "Harry Potter", groups: [:wizards, :gryffindor, :students]}
      hermione = %User{id: 2, name: "Hermione Granger", groups: [:wizards, :gryffindor, :students]}
      voldemort = %User{id: 3, name: "Tom Riddle", groups: [:wizards, :slytherin, :dark_wizards]}
      draco = %User{id: 4, name: "Draco Malfoy", groups: [:wizards, :slytherin, :students, :dark_wizards]}
      dumbledore = %User{id: 5, name: "Albus Dumbledore", groups: [:wizards, :professors, :headmasters]}
      # = %User{id: 6, name: "", groups: []}

      {:ok, flag_name: unique_atom(), harry: harry, hermione: hermione, voldemort: voldemort, draco: draco, dumbledore: dumbledore}
    end


    test "group beats boolean, actor beats all", %{flag_name: flag_name, harry: harry, hermione: hermione, voldemort: voldemort, draco: draco, dumbledore: dumbledore} do
      refute FunWithFlags.enabled?(flag_name, for: harry)
      refute FunWithFlags.enabled?(flag_name, for: hermione)
      refute FunWithFlags.enabled?(flag_name, for: voldemort)
      refute FunWithFlags.enabled?(flag_name, for: draco)
      refute FunWithFlags.enabled?(flag_name, for: dumbledore)

      FunWithFlags.enable(flag_name, for_group: :students)
      assert FunWithFlags.enabled?(flag_name, for: harry)
      assert FunWithFlags.enabled?(flag_name, for: hermione)
      refute FunWithFlags.enabled?(flag_name, for: voldemort)
      assert FunWithFlags.enabled?(flag_name, for: draco)
      refute FunWithFlags.enabled?(flag_name, for: dumbledore)

      FunWithFlags.disable(flag_name, for_group: :gryffindor)
      refute FunWithFlags.enabled?(flag_name, for: harry)
      refute FunWithFlags.enabled?(flag_name, for: hermione)
      refute FunWithFlags.enabled?(flag_name, for: voldemort)
      assert FunWithFlags.enabled?(flag_name, for: draco)
      refute FunWithFlags.enabled?(flag_name, for: dumbledore)

      FunWithFlags.enable(flag_name, for_actor: hermione)
      refute FunWithFlags.enabled?(flag_name, for: harry)
      assert FunWithFlags.enabled?(flag_name, for: hermione)
      refute FunWithFlags.enabled?(flag_name, for: voldemort)
      assert FunWithFlags.enabled?(flag_name, for: draco)
      refute FunWithFlags.enabled?(flag_name, for: dumbledore)

      FunWithFlags.enable(flag_name)
      refute FunWithFlags.enabled?(flag_name, for: harry)
      assert FunWithFlags.enabled?(flag_name, for: hermione)
      assert FunWithFlags.enabled?(flag_name, for: voldemort)
      assert FunWithFlags.enabled?(flag_name, for: draco)
      assert FunWithFlags.enabled?(flag_name, for: dumbledore)

      FunWithFlags.disable(flag_name, for_group: :dark_wizards)
      refute FunWithFlags.enabled?(flag_name, for: harry)
      assert FunWithFlags.enabled?(flag_name, for: hermione)
      refute FunWithFlags.enabled?(flag_name, for: voldemort)
      refute FunWithFlags.enabled?(flag_name, for: draco)
      assert FunWithFlags.enabled?(flag_name, for: dumbledore)

      FunWithFlags.disable(flag_name, for_actor: dumbledore)
      refute FunWithFlags.enabled?(flag_name, for: harry)
      assert FunWithFlags.enabled?(flag_name, for: hermione)
      refute FunWithFlags.enabled?(flag_name, for: voldemort)
      refute FunWithFlags.enabled?(flag_name, for: draco)
      refute FunWithFlags.enabled?(flag_name, for: dumbledore)

      FunWithFlags.enable(flag_name, for_actor: voldemort)
      refute FunWithFlags.enabled?(flag_name, for: harry)
      assert FunWithFlags.enabled?(flag_name, for: hermione)
      assert FunWithFlags.enabled?(flag_name, for: voldemort)
      refute FunWithFlags.enabled?(flag_name, for: draco)
      refute FunWithFlags.enabled?(flag_name, for: dumbledore)

      FunWithFlags.enable(flag_name, for_actor: harry)
      assert FunWithFlags.enabled?(flag_name, for: harry)
      assert FunWithFlags.enabled?(flag_name, for: hermione)
      assert FunWithFlags.enabled?(flag_name, for: voldemort)
      refute FunWithFlags.enabled?(flag_name, for: draco)
      refute FunWithFlags.enabled?(flag_name, for: dumbledore)
    end


    test "with conflicting group settings, DISABLED groups have the precedence", %{flag_name: flag_name, harry: harry, draco: draco, voldemort: voldemort} do
      FunWithFlags.disable(flag_name)
      refute FunWithFlags.enabled?(flag_name)
      refute FunWithFlags.enabled?(flag_name, for: harry)
      refute FunWithFlags.enabled?(flag_name, for: draco)
      refute FunWithFlags.enabled?(flag_name, for: voldemort)

      FunWithFlags.enable(flag_name, for_group: :students)
      refute FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: harry)
      assert FunWithFlags.enabled?(flag_name, for: draco)
      refute FunWithFlags.enabled?(flag_name, for: voldemort)

      FunWithFlags.disable(flag_name, for_group: :slytherin)
      refute FunWithFlags.enabled?(flag_name)
      assert FunWithFlags.enabled?(flag_name, for: harry)
      refute FunWithFlags.enabled?(flag_name, for: draco)
      refute FunWithFlags.enabled?(flag_name, for: voldemort)
    end
  end


  describe "looking up a flag after a delay (indirectly test the cache TTL, if present)" do
    alias FunWithFlags.Config

    test "the flag value is still set even after the TTL of the cache (regardless of the cache being present)" do
      flag_name = unique_atom()

      assert false == FunWithFlags.enabled?(flag_name)
      {:ok, true} = FunWithFlags.enable(flag_name)
      assert true == FunWithFlags.enabled?(flag_name)

      timetravel by: (Config.cache_ttl + 10_000) do
        assert true == FunWithFlags.enabled?(flag_name)
      end
    end
  end
end
