%%%-------------------------------------------------------------------
%%% @copyright (C) 2017, Aeternity Anstalt
%%%-------------------------------------------------------------------

-module(aec_blocks).

%% API
-export([prev_hash/1,
         height/1,
         target/1,
         txs/1,
         txs_hash/1,
         difficulty/1,
         time_in_msecs/1,
         pow/1,
         set_pow/3,
         set_target/2,
         miner/1,
         new/10,
         from_header_and_txs/2,
         to_header/1,
         serialize_to_binary/1,
         serialize_to_map/1,
         deserialize_from_binary/1,
         deserialize_from_map/1,
         hash_internal_representation/1,
         root_hash/1,
         validate/1,
         version/1]).

-import(aec_hard_forks, [protocol_effective_at_height/1]).

-ifdef(TEST).
-compile([export_all, nowarn_export_all]).
-endif.

-include("blocks.hrl").

%% block() can't be opaque since aec_block_genesis also needs to
%% be able to handle the raw #block{} record - TODO: change this
-type block() :: #block{}.
-type height() :: non_neg_integer().
-export_type([block/0, block_header_hash/0, height/0]).

-spec prev_hash(block()) -> block_header_hash().
prev_hash(Block) ->
    Block#block.prev_hash.

-spec height(block()) -> height().
height(Block) ->
    Block#block.height.

-spec target(block()) -> integer().
target(Block) ->
    Block#block.target.

-spec difficulty(block()) -> float().
difficulty(Block) ->
    aec_pow:target_to_difficulty(target(Block)).

time_in_msecs(Block) ->
    Block#block.time.

-spec root_hash(block()) -> binary().
root_hash(Block) ->
    Block#block.root_hash.

-spec miner(block()) -> aec_keys:pubkey().
miner(Block) ->
    Block#block.miner.

-spec version(block()) -> non_neg_integer().
version(Block) ->
    Block#block.version.

%% Sets the evidence of PoW,too,  for Cuckoo Cycle
-spec set_pow(block(), aec_pow:nonce(), aec_pow:pow_evidence()) -> block().
set_pow(Block, Nonce, Evd) ->
    Block#block{nonce = Nonce,
                pow_evidence = Evd}.

-spec pow(block()) -> aec_pow:pow_evidence().
pow(Block) ->
    Block#block.pow_evidence.
-spec set_target(block(), non_neg_integer()) -> block().
set_target(Block, Target) ->
    Block#block{target = Target}.

%% TODO: have a spec for list of transactions
-spec txs(block()) -> list(aetx_sign:signed_tx()).
txs(Block) ->
    Block#block.txs.

-spec txs_hash(block()) -> binary().
txs_hash(Block) ->
    Block#block.txs_hash.

-spec new(height(), block_header_hash(), state_hash(), txs_hash(),
          list(aetx_sign:signed_tx()), aec_pow:sci_int(),
          non_neg_integer(), non_neg_integer(), non_neg_integer(),
          miner_pubkey()) -> block().
new(Height, PrevHash, RootHash, TxsHash, Txs, Target, Nonce, Time, Version, Miner) ->
    #block{ height = Height
          , prev_hash = PrevHash
          , root_hash = RootHash
          , txs_hash  = TxsHash
          , txs       = Txs
          , target    = Target
          , nonce     = Nonce
          , time      = Time
          , version   = Version
          , miner     = Miner }.

-spec to_header(block()) -> aec_headers:header().
to_header(#block{height = Height,
                 prev_hash = PrevHash,
                 txs_hash = TxsHash,
                 root_hash = RootHash,
                 target = Target,
                 nonce = Nonce,
                 time = Time,
                 version = Version,
                 pow_evidence = Evd,
                 miner = Miner}) ->
    #header{height = Height,
            prev_hash = PrevHash,
            txs_hash = TxsHash,
            root_hash = RootHash,
            target = Target,
            nonce = Nonce,
            time = Time,
            pow_evidence = Evd,
            version = Version,
            miner = Miner}.

from_header_and_txs(#header{height = Height,
                            prev_hash = PrevHash,
                            txs_hash = TxsHash,
                            root_hash = RootHash,
                            target = Target,
                            nonce = Nonce,
                            time = Time,
                            pow_evidence = Evd,
                            version = Version,
                            miner = Miner}, Txs) ->
    #block{height = Height,
           prev_hash = PrevHash,
           txs_hash = TxsHash,
           root_hash = RootHash,
           target = Target,
           nonce = Nonce,
           time = Time,
           version = Version,
           pow_evidence = Evd,
           txs = Txs,
           miner = Miner
          }.

serialize_to_binary(B = #block{}) ->
    Hdr = aec_headers:serialize_to_binary(to_header(B)),
    Txs = [ aetx_sign:serialize_to_binary(Tx) || Tx <- B#block.txs ],
    Vsn = B#block.version,
    {ok, Template} = serialization_template(Vsn),
    aec_object_serialization:serialize(
        block,
        Vsn,
        Template,
        [{header, Hdr}, {txs, Txs}]).

deserialize_from_binary(Bin) ->
    {block, Vsn, _RawFields} =
        aec_object_serialization:deserialize_type_and_vsn(Bin),
    case serialization_template(Vsn) of
        {ok, Template} ->
            [{header, Hdr0}, {txs, Txs0}] =
                aec_object_serialization:deserialize(block, Vsn, Template, Bin),
            Hdr = aec_headers:deserialize_from_binary(Hdr0),
            Txs = [ aetx_sign:deserialize_from_binary(Tx) || Tx <- Txs0 ],
            {ok, from_header_and_txs(Hdr, Txs)};
        Err = {error, _} ->
            Err
    end.

serialization_template(Vsn) when Vsn >= ?GENESIS_VERSION andalso Vsn =< ?PROTOCOL_VERSION ->
    {ok, [{header, binary}, {txs, [binary]}]};
serialization_template(Vsn) ->
    {error, {bad_block_vsn, Vsn}}.

serialize_to_map(B = #block{}) ->
    #{<<"height">> => height(B),
      <<"prev_hash">> => prev_hash(B),
      <<"state_hash">> => B#block.root_hash,
      <<"txs_hash">> => B#block.txs_hash,
      <<"target">> => B#block.target,
      <<"nonce">> => B#block.nonce,
      <<"time">> => B#block.time,
      <<"version">> => B#block.version,
      <<"pow">> => B#block.pow_evidence,
      <<"transactions">> => B#block.txs,
      <<"miner">> => B#block.miner
     }.

deserialize_from_map(#{<<"nonce">> := Nonce}) when Nonce < 0;
                                                   Nonce > ?MAX_NONCE ->
    %% Prevent forging a solution without performing actual work by prefixing digits
    %% to a valid nonce (produces valid PoW after truncating to the allowed range)
    {error, bad_nonce};
deserialize_from_map(#{<<"height">> := Height,
                       <<"prev_hash">> := PrevHash,
                       <<"state_hash">> := RootHash,
                       <<"txs_hash">> := TxsHash,
                       <<"target">> := Target,
                       <<"nonce">> := Nonce,
                       <<"time">> := Time,
                       <<"version">> := Version,
                       <<"pow">> := PowEvidence,
                       <<"transactions">> := Txs,
                       <<"miner">> := Miner}) ->
    {ok, #block{
            height = Height,
            prev_hash = PrevHash,
            root_hash = RootHash,
            txs_hash = TxsHash,
            target = Target,
            nonce = Nonce,
            time = Time,
            version = Version,
            txs = Txs,
            pow_evidence = PowEvidence,
            miner = Miner}}.

-spec hash_internal_representation(block()) -> {ok, block_header_hash()}.
hash_internal_representation(B = #block{}) ->
    aec_headers:hash_header(to_header(B)).


-spec validate(block()) -> ok | {error, term()}.
validate(Block) ->
    % since trees are required for transaction signature validation, this is
    % performed while applying transactions
    Validators = [fun validate_txs_hash/1],
    aeu_validation:run(Validators, [Block]).

-spec validate_txs_hash(block()) -> ok | {error, malformed_txs_hash}.
validate_txs_hash(#block{txs = Txs,
                         txs_hash = BlockTxsHash}) ->
    case aec_txs_trees:pad_empty(aec_txs_trees:root_hash(aec_txs_trees:from_txs(
                                                           Txs))) of
        BlockTxsHash ->
            ok;
        _Other ->
            {error, malformed_txs_hash}
    end.
