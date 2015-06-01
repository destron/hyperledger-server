defmodule Hyperledger.TestFactory do
  import Hyperledger.ParamsHelpers, only: [underscore_keys: 1]
  import Hyperledger.Crypto
  
  alias Hyperledger.SecretStore
  alias Hyperledger.Node
  alias Hyperledger.Asset
  
  def create_node(n) do
    Node.create n, "http://localhost-#{n}", "#{n}"
  end

  def create_primary do
    primary = create_node(1)
    System.put_env("NODE_URL", primary.url)
  end
  
  def create_asset(contract \\ "123", secret_store \\ nil) do
    params = underscore_keys(asset_params(contract, secret_store))
    %Asset{}
    |> Asset.changeset(params["asset"])
    |> Asset.create
  end
  
  def asset_params(contract \\ "123", secret_store \\ nil) do
    {pk, sk} = key_pair
    {pa_pk, pa_sk} = key_pair
    
    if secret_store do
      SecretStore.put(secret_store, pk, sk)
      SecretStore.put(secret_store, pa_pk, pa_sk)
    end
    
    %{
      asset: %{
        hash: hash(contract),
        publicKey: pk,
        primaryAccountPublicKey: pa_pk
      }
    }
  end
  
  def account_params(asset_hash, secret_store) do
    {pk, sk} = key_pair
    SecretStore.put(secret_store, pk, sk)
    
    %{
      account: %{
        assetHash: asset_hash,
        publicKey: pk
      }
    }
  end
  
  def issue_params(asset_hash) do
    %{
      issue: %{
        uuid: Ecto.UUID.generate,
        assetHash: asset_hash,
        amount: 100
      }
    }
  end
  
  def transfer_params(source, dest) do
    %{
      transfer: %{
        uuid: Ecto.UUID.generate,
        amount: 100,
        sourcePublicKey: source,
        destinationPublicKey: dest
      }
    }
  end
  
  def log_entry_params(command, params, public_key, secret_store) do
    secret_key = SecretStore.get(secret_store, public_key)
    signature = sign(params, secret_key)
    %{
      logEntry: %{
        command: command,
        data: Poison.encode!(params),
        authentication_key: public_key,
        signature: signature
      }
    }
  end
end