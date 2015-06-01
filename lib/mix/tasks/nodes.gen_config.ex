defmodule Mix.Tasks.Hyperledger.Nodes.GenConfig do
  use Mix.Task
  
  @shortdoc "Generate a JSON configuration document"
  
  def run([n, db_username]) do
    (1..String.to_integer(n))
    |> Enum.map(fn n ->
         {public, secret} = Hyperledger.Crypto.key_pair
         port = 4000 + n
         %{
           id: n,
           public_key: public,
           secret_key: Base.encode16(secret),
           port: port,
           url: "localhost:#{port}",
           db: "ecto://#{db_username}@localhost/hl_dev_#{n}"
         }
    end)
    |> Poison.encode!
    |> IO.puts
  end
  
end