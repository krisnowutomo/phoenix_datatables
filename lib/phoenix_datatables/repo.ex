defmodule PhoenixDatatables.Repo do
  @moduledoc """
  Provides a using macro which creates the `fetch_table` function.

      defmodule MyApp.Repo do
        use PhoenixDatatables.Repo
      end
  """

  @doc """
  Creates the `Repo.fetch_datatable` function.
  """
  defmacro __using__(_) do
    quote do
      def fetch_datatable(query, params, options \\ nil) do
        PhoenixDatatables.execute(query, params, __MODULE__, options)
      end

      @doc false # Sembunyikan dari dokumentasi publik jika tidak perlu
      # Fungsi helper untuk mendapatkan adapter repo yang sedang digunakan
      # __CALLER__.module akan berisi modul Repo yang memanggil `use` (misalnya MyApp.Repo)
      def get_repo_adapter do
        # Pastikan modul repo yang memanggil ini memiliki fungsi :adapter, 0
        caller_repo_module = __CALLER__.module

        if function_exported?(caller_repo_module, :adapter, 0) do
          caller_repo_module.adapter()
        else
          raise """
          PhoenixDatatables Error: The module `#{inspect caller_repo_module}`
          that uses `PhoenixDatatables.Repo` does not appear to be a valid Ecto Repo.
          It must have an `adapter/0` function.
          """
        end
      end
    end
  end

end
