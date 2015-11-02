defmodule Hyperledger.ModelTest.CommitConfirmation do
  use Hyperledger.ModelCase
    
  alias Hyperledger.SecretStore
  
  alias Hyperledger.CommitConfirmation
  alias Hyperledger.LogEntry
  
  defp changeset_for_asset do
    {:ok, secret_store} = SecretStore.start_link
    
    params = asset_params("{}", secret_store)
    public_key = params.asset[:publicKey]
    params = log_entry_params("asset/create", params, public_key, secret_store)
    LogEntry.changeset(%LogEntry{}, :create, params[:logEntry])
  end
  
  setup do
    create_primary
    {:ok, sk} = System.get_env("SECRET_KEY") |> Base.decode16
    
    {:ok, log_entry} = LogEntry.create(changeset_for_asset)
    data = LogEntry.as_json(log_entry)
    sig = sign(data, sk)
    {:ok, log_entry: log_entry, data: Poison.encode!(data), sig: sig}
  end
  
  test "changeset validates node existence", %{log_entry: log_entry, data: data, sig: sig} do
    params = %{
      log_entry_id: log_entry.id,
      node_id: 2,
      data: data,
      signature: sig
    }
    
    cs = CommitConfirmation.changeset(params)
    
    assert cs.valid? == false
  end
  
  test "changeset checks for signature authenticity", %{log_entry: log_entry, data: data} do
    {_pk, sk} = key_pair
    sig = sign(data, sk)
    
    params = %{
      log_entry_id: log_entry.id,
      node_id: 1,
      data: data,
      signature: sig
    }
    
    cs = CommitConfirmation.changeset(params)

    assert cs.valid? == false
  end
  
  test "create inserts a valid changeset", %{log_entry: log_entry, data: data, sig: sig} do
    params = %{
      log_entry_id: log_entry.id,
      node_id: 1,
      data: data,
      signature: sig
    }
    
    cs = CommitConfirmation.changeset(params)
    
    assert cs.valid? == true
    assert {:ok, %CommitConfirmation{}} = CommitConfirmation.create(cs)
  end
end