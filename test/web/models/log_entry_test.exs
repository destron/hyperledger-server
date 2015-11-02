defmodule Hyperledger.LogEntryModelTest do
  use Hyperledger.ModelCase
  
  import Mock
  
  alias Hyperledger.SecretStore
  
  alias Hyperledger.LogEntry
  alias Hyperledger.Asset
  alias Hyperledger.Account
  alias Hyperledger.Issue
  alias Hyperledger.Transfer
  alias Hyperledger.CommitConfirmation
  alias Hyperledger.Node
    
  defp changeset_for_asset do
    {:ok, secret_store} = SecretStore.start_link
    changeset_for_asset("123", secret_store)
  end
  
  defp changeset_for_asset(contract, secret_store) do
    params = asset_params(contract, secret_store)
    public_key = params.asset[:publicKey]
    gen_create_changeset("asset/create", params, public_key, secret_store)
  end
  
  defp changeset_for_account(asset_hash, secret_store) do
    params = account_params(asset_hash, secret_store)
    public_key = params.account[:publicKey]
    gen_create_changeset("account/create", params, public_key, secret_store)
  end
  
  defp changeset_for_issue(asset, secret_store) do
    params = issue_params(asset.hash)
    gen_create_changeset("issue/create", params, asset.public_key, secret_store)
  end
  
  defp changeset_for_transfer(source_key, dest_key, secret_store) do
    params = transfer_params(source_key, dest_key)
    gen_create_changeset("transfer/create", params, source_key, secret_store)
  end
  
  defp gen_create_changeset(command, params, public_key, secret_store) do
    params = log_entry_params(command, params, public_key, secret_store)
    LogEntry.changeset(%LogEntry{}, :create, params[:logEntry])
  end
  
  defp gen_insert_changeset(id, view_id, command, params, public_key, secret_store) do
    params =
      log_entry_params(command, params, public_key, secret_store)[:logEntry]
      |> Map.merge(%{id: id, view_id: view_id})
    LogEntry.changeset(%LogEntry{}, :insert, params)
  end
  
  defp sample_asset_data do
    Poison.encode!(asset_params)
  end
  
  setup do
    create_primary
    {:ok, secret_store} = SecretStore.start_link
    {:ok, secret_store: secret_store}
  end
  
  test "`changeset` for create validates signature" do
    {:ok, alt_store} = SecretStore.start_link
    {pk, _} = key_pair
    {_, sk} = key_pair
    SecretStore.put(alt_store, pk, sk)
    cs = gen_create_changeset("asset/create", asset_params, pk, alt_store)

    assert cs.valid? == false
    
    cs = changeset_for_asset
    
    assert cs.valid? == true
  end
  
  test "`changeset` validates data without the db", %{secret_store: secret_store} do
    {public, secret} = key_pair
    SecretStore.put(secret_store, public, secret)
    params =
      %{
        asset: %{
          hash: "GJ9D68b3RCw2HgjzEhtH+TjMcaiYTNntB4W8xa8FhA==",
          publicKey: public,
          primaryAccountPublicKey: "foo bar"
        }
      }
    cs = gen_create_changeset("asset/create", params, public, secret_store)
    assert cs.valid? == false
  end
  
  test "`changeset` for insert validates id and view", %{secret_store: secret_store} do
    params = asset_params("{}", secret_store)
    public_key = params.asset[:publicKey]
    cs = gen_insert_changeset(nil, 1, "asset/create", params, public_key, secret_store)
    
    assert cs.valid? == false
    
    cs = gen_insert_changeset(1, 1, "asset/create", params, public_key, secret_store)
    
    assert cs.valid? == true
  end
  
  test "creating the first log entry sets the id and view to 1" do
    {:ok, log_entry} = LogEntry.create(changeset_for_asset)
    
    assert log_entry.id   == 1
    assert log_entry.view_id == 1
  end
  
  test "creating a log entry also appends a pre-prepare from self" do
    {:ok, log_entry} = LogEntry.create(changeset_for_asset)
    
    assert Repo.get(LogEntry, log_entry.id).pre_prepared == true
    assert Repo.all(assoc(log_entry, :pre_prepares)) |> Enum.count == 1
  end
  
  test "creating a log entry with only one node prepares and commits immediately" do
    {:ok, log_entry} = LogEntry.create(changeset_for_asset)
    log_entry = Repo.get(LogEntry, log_entry.id)
    
    assert log_entry.prepared == true
    assert log_entry.committed == true
  end
  
  test "after create a primary broadcasts a pre-prepare to other nodes" do
    with_mock Node, [:passthrough], broadcast: fn _, _, _ -> nil end do
      {:ok, log_entry} = LogEntry.create(changeset_for_asset)
      data = LogEntry.as_json(log_entry)
      
      assert called(Node.broadcast(log_entry.id, "log", data))
    end
  end
  
  test "after create a replica broadcasts a prepare to other nodes" do
    node = create_node(2)
    System.put_env("NODE_URL", node.url)
    
    with_mock Node, [:passthrough], broadcast: fn _, _, _ -> nil end do
      {:ok, log_entry} =
        LogEntry.insert(
          id: 1,
          view_id: 1,
          command: "asset/create",
          data: changeset_for_asset.changes.data,
          prepare_confirmations: [%{node_id: 1, signature: "temp_signature"}],
          commit_confirmations: []
        )
      data = LogEntry.as_json(log_entry)
      
      assert called(Node.broadcast(log_entry.id, "prepare", data))
    end
  end
  
  test "a log entry marked as prepared broadcasts a commit to other nodes" do
    create_node(2)
    cs = changeset_for_asset
    
    with_mock Node, [:passthrough], broadcast: fn _, _, _ -> nil end do
      LogEntry.create(cs)
      LogEntry.insert(
        id: 1,
        view_id: 1,
        command: "asset/create",
        data: cs.changes.data,
        prepare_confirmations: [%{node_id: 2, signature: "temp_signature"}],
        commit_confirmations: []
      )
      log_entry = Repo.get(LogEntry, 1)
      data = LogEntry.as_json(log_entry)
      
      assert called(Node.broadcast(log_entry.id, "commit", data))
    end
  end
  
  test "commit confirmations are appended to the record and become marked as committed" do
    create_node(2)
    LogEntry.create(changeset_for_asset)
    LogEntry.insert(
      id: 1,
      view_id: 1,
      command: "asset/create",
      data: sample_asset_data,
      prepare_confirmations: [%{node_id: 2, signature: "temp_signature"}],
      commit_confirmations: []
    )
    LogEntry.insert(
      id: 1,
      view_id: 1,
      command: "asset/create",
      data: sample_asset_data,
      prepare_confirmations: [],
      commit_confirmations: [%{node_id: 2, signature: "temp_signature"}]
    )
    
    assert Repo.all(CommitConfirmation) |> Enum.count == 2
    assert Repo.get(LogEntry, 1).committed == true
  end
  
  # test "inserting a log entry returns error if primary has no existing record" do
  #   assert {:error, _} = LogEntry.insert id: 1, view_id: 1, command: "asset/create",
  #     data: sample_asset_data, prepare_confirmations: [], commit_confirmations: []
  # end
  #
  # test "inserting a log entry returns ok if primary has record which matches" do
  #   LogEntry.create(changeset_for_asset)
  #   assert {:ok, %LogEntry{}} = LogEntry.insert(
  #     id: 1, view_id: 1, command: "asset/create", data: sample_asset_data,
  #     prepare_confirmations: [%{node_id: 1, signature: "temp_signature"},
  #                             %{node_id: 2, signature: "temp_signature"}],
  #     commit_confirmations: [])
  #   assert Repo.all(PrepareConfirmation) |> Enum.count == 2
  #   assert Repo.get(LogEntry, 1).prepared == true
  # end
  #
  # test "inserting a log entry returns ok if node is not primary" do
  #   node = create_node(2)
  #   System.put_env("NODE_URL", node.url)
  #
  #   assert {:ok, %LogEntry{}} = LogEntry.insert(
  #     id: 1, view_id: 1, command: "asset/create", data: sample_asset_data,
  #     prepare_confirmations: [%{node_id: 1, signature: "temp_signature"}],
  #     commit_confirmations: [])
  # end
  #
  # test "inserting a log entry saves the confirmations and appends its own" do
  #   node = create_node(2)
  #   System.put_env("NODE_URL", node.url)
  #
  #   LogEntry.insert id: 1, view_id: 1, command: "asset/create",
  #     data: sample_asset_data, prepare_confirmations: [%{
  #       node_id: 1, signature: "temp_signature"}], commit_confirmations: []
  #
  #   assert Repo.all(PrepareConfirmation) |> Enum.count == 2
  #
  #   LogEntry.insert id: 1, view_id: 1, command: "asset/create", data: sample_asset_data,
  #     prepare_confirmations: [%{node_id: 1, signature: "temp_signature"}],
  #     commit_confirmations: [%{node_id: 1, signature: "temp_signature"}]
  #
  #   assert Repo.all(CommitConfirmation) |> Enum.count == 2
  # end
  
  test "adding a prepare marks as prepared if quorum reached" do
    node = create_node(2)
    {:ok, log_entry} = LogEntry.create(changeset_for_asset)
    
    assert log_entry.pre_prepared == true
    assert log_entry.prepared == false
    
    LogEntry.add_prepare(log_entry, node.id, "temp_signature")
    
    assert Repo.get(LogEntry, log_entry.id).prepared == true
  end
  
  test "when a log entry is marked as prepared the node adds a commit confirmation" do
    node = create_node(2)
    {:ok, log_entry} = LogEntry.create(changeset_for_asset)

    assert Repo.all(assoc(log_entry, :commit_confirmations)) == []
    
    LogEntry.add_prepare(log_entry, node.id, "temp_signature")
    
    assert Repo.all(assoc(log_entry, :commit_confirmations)) |> Enum.count == 1
  end
  
  test "when a log entry passes the quorum for commit confirmations it is marked as committed and executed" do
    node = create_node(2)
    {:ok, log_entry} = LogEntry.create(changeset_for_asset)
    LogEntry.add_prepare(log_entry, node.id, "temp_signature")
    
    log_entry = Repo.get(LogEntry, log_entry.id)
    assert log_entry.committed == false

    LogEntry.add_commit(log_entry, node.id, "temp_signature")
    
    log_entry = Repo.get(LogEntry, log_entry.id)
    assert log_entry.prepared  == true
    assert log_entry.committed == true
    assert log_entry.executed  == true
  end
  
  test "log entries are executed in order", %{secret_store: secret_store} do
    node = create_node(2)
    {:ok, log_entry_1} = LogEntry.create(changeset_for_asset("123", secret_store))
    {:ok, log_entry_2} = LogEntry.create(changeset_for_asset("456", secret_store))
    LogEntry.add_prepare(log_entry_1, node.id, "temp_signature")
    LogEntry.add_prepare(log_entry_2, node.id, "temp_signature")
    LogEntry.add_commit(log_entry_2, node.id, "temp_signature")
    
    assert Repo.all(Asset) |> Enum.count == 0

    LogEntry.add_commit(log_entry_1, node.id, "temp_signature")
    
    assert Repo.all(Asset) |> Enum.count == 2
  end
  
  test "executing a log entry saves the accepted state", %{secret_store: secret_store} do
    log_entry = changeset_for_asset("123", secret_store) |> Repo.insert
    
    assert log_entry.accepted == nil
    
    LogEntry.execute(log_entry)
    
    assert Repo.get(LogEntry, log_entry.id).accepted == true
  end
  
  test "executing log entry creates asset with a primary account" do
    log_entry = changeset_for_asset |> Repo.insert
    
    LogEntry.execute(log_entry)
    
    assert Repo.all(Asset)   |> Enum.count == 1
    assert Repo.all(Account)  |> Enum.count == 1
  end
  
  test "executing log entry creates account", %{secret_store: secret_store} do
    {:ok, asset} = create_asset
    log_entry = changeset_for_account(asset.hash, secret_store) |> Repo.insert
    
    LogEntry.execute(log_entry)
    
    assert Repo.all(LogEntry) |> Enum.count == 1
    assert Repo.all(Account)  |> Enum.count == 2
  end
  
  test "executing log entry creates issue and changes primary wallet balances", %{secret_store: secret_store} do
    {:ok, asset} = create_asset("123", secret_store)
    log_entry = changeset_for_issue(asset, secret_store) |> Repo.insert
    
    LogEntry.execute(log_entry)
       
    assert Repo.all(Issue)    |> Enum.count == 1
    assert Repo.get(Account, asset.primary_account_public_key).balance == 100
  end
  
  test "executing log entry creates transfer and changes wallet balances", %{secret_store: secret_store} do
    {:ok, asset} = create_asset("123", secret_store)
    source = Repo.one(assoc(asset, :primary_account))
    %{ source | balance: 100 } |> Repo.update
    {dest_key, _} = key_pair
    %Account{public_key: dest_key, asset_hash: asset.hash} |> Repo.insert
    
    log_entry =
      changeset_for_transfer(
        asset.primary_account_public_key,
        dest_key,
        secret_store
      ) |> Repo.insert
    
    LogEntry.execute(log_entry)
    
    assert Repo.all(Transfer) |> Enum.count == 1
    assert Repo.get(Account, asset.primary_account_public_key).balance == 0
    assert Repo.get(Account, dest_key).balance == 100
  end
end