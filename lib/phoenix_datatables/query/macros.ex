defmodule PhoenixDatatables.Query.Macros do

  @moduledoc false

  # make a simple AST representing blank Ecto table bindings so that
  # 'name' is bound to num(th) position (0 base)
  # e.g. bind_number(3, :t) = [_, _, _, t]
  defp bind_number(num, name \\ :t) do
    blanks =
      for _ <- 0..num do
        {:_, [], Elixir}
      end

    Enum.drop(blanks, 1) ++ [{name, [], Elixir}]
  end

  def get_adapter() do
    case Application.fetch_env(:phoenix_datatables, :adapter) do
      {:ok, adapter_name} when is_atom(adapter_name) ->
        case adapter_name do
          :postgres -> Ecto.Adapters.Postgres
          :myxql -> Ecto.Adapters.MyXQL
          _ -> nil
        end

      {:ok, invalid} ->
        raise """
        Invalid datatables adapter configuration.
        Expected string, got: #{inspect(invalid)}
        """

      :error ->
        raise """
        Datatables config adapter not found.
        Please configure it in your config files:
        
        config :lib_datatables,
          adapter: "mysql"  # or "postgres", etc
        """
    end
  end

  defp def_order_relation(num) do
    bindings = bind_number(num)    

    quote do
      defp order_relation(queryable, unquote(num), dir, column, nil) do
        order_by(queryable, unquote(bindings), [{^dir, field(t, ^column)}])
      end

      defp order_relation(queryable, unquote(num), dir, column, options) when is_list(options) do
        adapters = PhoenixDatatables.Query.Macros.get_adapter()
        if dir == :desc && options[:nulls_last] do
          case adapters do
            Ecto.Adapters.Postgres ->
              order_by(queryable, unquote(bindings), [
                fragment("? DESC NULLS LAST", field(t, ^column))
              ])
            Ecto.Adapters.MyXQL ->
              order_by(queryable, unquote(bindings), [
                fragment("IS NULL(?) ASC, ? DESC", field(t, ^column), field(t, ^column))
              ])
            _ ->
            raise "PhoenixDatatables: Unsupported Ecto adapter for NULLS LAST ordering"
          end
        else
          order_relation(queryable, unquote(num), dir, column, nil)
        end
      end
    end
  end

  defp def_search_relation(num) do
    bindings = bind_number(num)    

    quote do
      defp search_relation(dynamic, unquote(num), attribute, search_term) do
        adapters = PhoenixDatatables.Query.Macros.get_adapter()
        case adapters do
          Ecto.Adapters.Postgres ->
            dynamic(
              unquote(bindings),
              fragment("CAST(? AS TEXT) ILIKE ?", field(t, ^attribute), ^search_term) or ^dynamic
            )
          Ecto.Adapters.MyXQL ->
            dynamic(
              unquote(bindings),
              fragment("CAST(? AS CHAR) LIKE ?", field(t, ^attribute), ^search_term) or ^dynamic
            )
          _ ->
            raise "PhoenixDatatables: Unsupported Ecto adapter for search_relation"
        end
      end
    end
  end

  defp def_search_relation_and(num) do
    bindings = bind_number(num)    

    quote do
      defp search_relation_and(dynamic, unquote(num), attribute, search_term) do
        adapters = PhoenixDatatables.Query.Macros.get_adapter()
        case adapters do
          Ecto.Adapters.Postgres ->
            dynamic(
              unquote(bindings),
              fragment("CAST(? AS TEXT) ILIKE ?", field(t, ^attribute), ^search_term) and ^dynamic
            )
          Ecto.Adapters.MyXQL ->
            dynamic(
              unquote(bindings),
              fragment("CAST(? AS CHAR) LIKE ?", field(t, ^attribute), ^search_term) or ^dynamic
            )
          _ ->
            raise "PhoenixDatatables: Unsupported Ecto adapter for search_relation"
        end
        
      end
    end
  end

  defmacro __using__(arg) do
    defines_count =
      case arg do
        [] ->
          25

        num when is_integer(num) ->
          num

        arg ->
          raise """
            unknown args #{inspect(arg)} for
            PhoenixDatatables.Query.Macros.__using__,
            provide a number or nothing"
          """
      end

    order_relations = Enum.map(0..defines_count, &def_order_relation/1)
    search_relations = Enum.map(0..defines_count, &def_search_relation/1)
    search_relations_and = Enum.map(0..defines_count, &def_search_relation_and/1)

    quote do
      unquote(order_relations)
      defp search_relation(queryable, nil, _, _), do: queryable
      unquote(search_relations)
      unquote(search_relations_and)
    end
  end
end
