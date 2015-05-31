# Hyperledger Reference Implementation

This is the reference implementation of Hyperledger. Hyperledger is a protocol
for creating and transferring assets on decentralised ledgers. It's designed to
be run in environments where the set of replicating nodes is known. All the
resources in the system are exposed through a hypermedia interface to allow for
loose coupling between parties, especially the clients.

This software is currently in beta so run at your own risk.

## Installation

Prerequisites; Elixir v1.0.4, PostgreSQL

1. Install dependencies with `mix deps.get`
2. Modify the `DATABASE_URL` environment variable in the `.env` file to
   reference your Postgres user
3. Create a database with `mix ecto.create`
4. Run the migrations with `mix ecto.migrate`
5. Create a database entry for the local node; run `iex -S mix` and then run
   `> Hyperledger.Node.create(1, System.get_env("NODE_URL"), System.get_env("PUBLIC_KEY"))`
6. Start the server with `mix phoenix.server`

The server should now be running at `localhost:4000`.

## Domain Model

There are four core concepts behind the Hyperledger domain model:

1. Assets — assets are defined by a contract document. The document is hashed
   with SAH256 and this has is used as the asset identifier. Contract documents
   can be any type of file, but the preferred type is a JSON document which is
   easily parseable by machines and people. Hyperledger does not store the
   document itself, only the hash. This enables you to keep the details of the
   asset private by handing out the contract to specific parties. When an asset
   is first registered it is associated with a public key; only that key is
   authorised to create new units of that asset. For more information see [Ian
   Grigg's paper on Ricardian Contracts]
   (http://iang.org/papers/ricardian_contract.html).
2. Accounts — accounts are identified by a public key and are tied to a
   specific asset; if you want to hold multiple assets you need to create one
   account per asset. Account balances must always be positive. When you
   register an asset you create an account at the same time. This is known as
   the 'primary' account for that asset, and is the only account that can
   receive new units of an asset. Transfers out of an account must be
   authorised by the associated key.
3. Issues — issuing units is the process of introducing new units into the
   system. Issuing must be authorised by the key associated with the asset and
   can only be received by the primary account for that asset.
4. Transfers — units can be transferred from one account to another. The
   key of the source account must be used to authorise transfers and the
   account balance can not fall below zero.

All keys used in Hyperledger are EC keys on the curve 'secp256k1'.

## API

The API is a standard hypermedia interface exposed over HTTP. The hypermedia
format used is [UBER](http://uberhypermedia.org). Authors of client libraries
are encouraged to use (or create, if none exist) an intermediate library that
deals with the UBER representation, rather than assume a fixed structure for
requests or responses. However, as the API is not yet fully self-descriptive it
is worth looking at the [Hyperledger CLI]
(https://github.com/hyperledger/hyperledger-cli) for more information.

When POSTing new resources, the key for the new resource must be used to sign
the message to ensure authenticity. The key and the signature should be encoded
as uppercase hex, and used to generate an 'authorisation' (case sensitive)
header as follows:

    authorisation: Hyper Key=<public key>, Signature=<signature>

New resources are created by POSTing authenticated JSON resources. All binary
strings (hashes and keys) should be encoded as hex strings. The resources
should be structured as follows:

    POST /assets
    {
      "asset": {
        "hash": <SHA256 hash of contract document>,
        "publicKey": <asset public key>,
        "primaryAccountPublicKey": <primary account public key>
      }  
    }
    
    POST /accounts
    {
      "account": {
        "assetHash": <asset hash>,
        "publicKey": <account public key>
      }
    }
    
    POST /asset/<asset hash>/issues
    {
      "issue": {
        "uuid": <UUID version 4>,
        "assetHash": <asset hash>,
        "amount": <integer amount>
      }
    }
    
    POST /transfers
    {
      "transfer": {
        "uuid": <UUID version 4>,
        "sourcePublicKey": <source account public key>,
        "destinationPublicKey": <destination account public key>,
        "amount": <integer amount>
    }

## Replication

An Hyperledger pool is a set of servers which replicate an ordered list of
write operations. Read operations are not ordered, and it is the responsibility
of clients to check the status of operations against the other servers in the
pool.