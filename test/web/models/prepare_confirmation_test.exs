defmodule Hyperledger.ModelTest.PrepareConfirmation do
  use Hyperledger.ModelCase
    
  alias Hyperledger.SecretStore
  
  alias Hyperledger.PrepareConfirmation
  alias Hyperledger.LogEntry
  alias Hyperledger.Node
  
  defp changeset_for_asset do
    {:ok, secret_store} = SecretStore.start_link
    
    params = asset_params("{}", secret_store)
    public_key = params.asset[:publicKey]
    params = log_entry_params("asset/create", params, public_key, secret_store)
    LogEntry.changeset(%LogEntry{}, :create, params[:logEntry])
  end
  
  setup do
    {pk, sk} = key_pair
    pk = Base.encode16(pk)
    primary = Node.create(1, "http://localhost:4000", pk)
    System.put_env("NODE_URL", primary.url)
    
    {:ok, log_entry} = LogEntry.create(changeset_for_asset)
    data = LogEntry.as_json(log_entry, false)
    sig = sign(data, sk) |> Base.encode16
    {:ok, log_entry: log_entry, data: Poison.encode!(data), sig: sig}
  end
  
  test "changeset validates node existence", %{log_entry: log_entry, data: data, sig: sig} do
    params = %{
      log_entry_id: log_entry.id,
      node_id: 2,
      data: data,
      signature: sig
    }
    
    cs = PrepareConfirmation.changeset(params)
    
    assert cs.valid? == false
  end
  
  test "changeset checks for signature authenticity", %{log_entry: log_entry, data: data} do
    {_pk, sk} = key_pair
    sig = sign(data, sk) |> Base.encode16
    
    params = %{
      log_entry_id: log_entry.id,
      node_id: 1,
      data: data,
      signature: sig
    }
    
    cs = PrepareConfirmation.changeset(params)

    assert cs.valid? == false
  end
  
  test "create inserts a valid changeset", %{log_entry: log_entry, data: data, sig: sig} do
    params = %{
      log_entry_id: log_entry.id,
      node_id: 1,
      data: data,
      signature: sig
    }
    
    cs = PrepareConfirmation.changeset(params)
    
    assert cs.valid? == true
    assert {:ok, %PrepareConfirmation{}} = PrepareConfirmation.create(cs)
  end
end