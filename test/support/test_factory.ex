defmodule Hyperledger.TestFactory do
  import Hyperledger.ParamsHelpers, only: [underscore_keys: 1]

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
    hash = :crypto.hash(:sha256, contract)
    {pk, sk} = key_pair
    {pa_pk, pa_sk} = key_pair
    pk = Base.encode16(pk)
    pa_pk = Base.encode16(pa_pk)
    
    if secret_store do
      SecretStore.put(secret_store, pk, sk)
      SecretStore.put(secret_store, pa_pk, pa_sk)
    end
    
    %{
      asset: %{
        hash: Base.encode16(hash),
        publicKey: pk,
        primaryAccountPublicKey: pa_pk
      }
    }
  end
  
  def account_params(asset_hash, secret_store) do
    {pk, sk} = key_pair
    pk = Base.encode16(pk)
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
    signature = sign(params, secret_key) |> Base.encode16
    %{
      logEntry: %{
        command: command,
        data: Poison.encode!(params),
        authentication_key: public_key,
        signature: signature
      }
    }
  end
  
  def sign(params, secret_key) do
    :crypto.sign(:ecdsa, :sha256, Poison.encode!(params), [secret_key, :secp256k1])
  end
  
  def key_pair do
    :crypto.generate_key(:ecdh, :secp256k1)
  end
end