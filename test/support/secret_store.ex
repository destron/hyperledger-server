defmodule Hyperledger.SecretStore do
  @moduledoc """
  Based on the KV store from the Elixir docs.
  Keys are public keys, values are secret keys.
  """

  @doc """
  Starts a new store for secret keys.
  """
  def start_link do
    Agent.start_link(fn -> HashDict.new end)
  end

  @doc """
  Gets a secret key from the store by public key.
  """
  def get(store, key) do
    Agent.get(store, &HashDict.get(&1, key))
  end

  @doc """
  Puts the secret key for the given public key in the store.
  """
  def put(store, key, value) do
    Agent.update(store, &HashDict.put(&1, key, value))
  end
end