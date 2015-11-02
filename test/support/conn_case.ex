defmodule Hyperledger.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  imports other functionalities to make it easier
  to build and query models.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate
  
  using do
    quote do
      # Import conveniences for testing with connections
      use Phoenix.ConnTest
      # Alias the data repository and import query/model functions
      alias Hyperledger.Repo
      import Ecto.Model
      import Ecto.Query, only: [from: 2]
      # Import URL helpers from the router
      import Hyperledger.Router.Helpers
      # The default endpoint for testing
      @endpoint Hyperledger.Endpoint
      # Import utility functions from this module
      import Hyperledger.ConnCase
      # Import factory functions
      import Hyperledger.TestFactory
      import Hyperledger.Crypto
      
      def post_authentic_json(url, params, {public, secret}) do
        signature = Hyperledger.Crypto.sign(params, secret)
        conn()
        |> put_req_header("content-type", "application/json")
        |> put_req_header("authorization", "Hyper Key=#{public}, Signature=#{signature}")
        |> post url, Poison.encode!(params)
      end
    end
  end

  setup tags do
    unless tags[:async] do
      Ecto.Adapters.SQL.restart_test_transaction(Hyperledger.Repo, [])
    end
    
    on_exit fn ->
      System.delete_env("NODE_URL")
    end
    
    :ok
  end
end