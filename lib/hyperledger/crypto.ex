defmodule Hyperledger.Crypto do
  
  @curve :secp256k1
  @digest :sha256
  
  def key_pair do
    {public, secret} = :crypto.generate_key(:ecdh, @curve)
    {Base.encode16(public), secret}
  end
  
  def sign(data, secret) do
    message = Poison.encode!(data)
    :crypto.sign(:ecdsa, @digest, message, [secret, @curve])
    |> Base.encode16
  end
  
  def verify(message, signature, public) do
    :crypto.verify(:ecdsa, @digest, message, signature, [public, @curve])
  end
  
  def hash(message) do
    :crypto.hash(@digest, message) |> Base.encode16
  end
end
