%%%-------------------------------------------------------------------
%% @doc
%% == Blockchain Proof of Coverage Path Element V2 ==
%%%-------------------------------------------------------------------
-module(blockchain_poc_path_element_v2).

-include("blockchain_utils.hrl").
-include_lib("helium_proto/include/blockchain_txn_poc_receipts_v2_pb.hrl").

-export([
         new/3,
         challengee/1,
         receipt/1, add_receipt/2,
         witnesses/1, add_witness/2,
         print/1
        ]).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-type poc_element() :: #blockchain_poc_path_element_v2_pb{}.
-type poc_path() :: [poc_element()].

-export_type([poc_element/0, poc_path/0]).

-spec new(Challengee :: libp2p_crypto:pubkey_bin(),
          Receipt :: blockchain_poc_receipt_v2:poc_receipt() | undefined,
          Witnesses :: blockchain_poc_witness_v2:poc_witnesses()) -> poc_element().
new(Challengee, Receipt, Witnesses) ->
    #blockchain_poc_path_element_v2_pb{
       challengee=Challengee,
       receipt=Receipt,
       witnesses=Witnesses
      }.

-spec challengee(Element :: poc_element()) -> libp2p_crypto:pubkey_bin().
challengee(Element) ->
    Element#blockchain_poc_path_element_v2_pb.challengee.

-spec receipt(Element :: poc_element()) -> blockchain_poc_receipt_v2:poc_receipt() | undefined.
receipt(Element) ->
    Element#blockchain_poc_path_element_v2_pb.receipt.

-spec add_receipt(Element :: poc_element(),
                  Receipt :: blockchain_poc_receipt_v2:poc_receipt()) -> poc_element().
add_receipt(Element, Receipt) ->
    case receipt(Element) of
        R when R == Receipt ->
            %% Readding the same receipt should not be allowed
            {error, receipt_replay};
        _ ->
            Element#blockchain_poc_path_element_v2_pb{receipt=Receipt}
    end.

-spec add_witness(Element :: poc_element(),
                  Witness :: blockchain_poc_witness_v2:poc_witness()) -> poc_element().
add_witness(Element = #blockchain_poc_path_element_v2_pb{witnesses=Witnesses}, Witness) ->
    %% Only add a witness to this path element if:
    %% 1. The number of witnesses for this path element is less than 5
    %% 2. It has not been a witness for this path element earlier
    case has_witness(Element, Witness) of
        false ->
            case length(witnesses(Element)) < 5 of
                false ->
                    {error, max_witnesses};
                true ->
                    %% ok to add
                    Element#blockchain_poc_path_element_v2_pb{witnesses=lists:sort([Witness | Witnesses])}
            end;
        true ->
            {error, witness_already_added}
    end.

-spec has_witness(Element :: poc_element(),
                  Witness :: blockchain_poc_witness_v2:poc_witness()) -> boolean().
has_witness(#blockchain_poc_path_element_v2_pb{witnesses=Witnesses}, Witness) ->
    lists:member(Witness, Witnesses).

-spec witnesses(Element :: poc_element()) -> blockchain_poc_witness_v2:poc_witnesses().
witnesses(Element) ->
    Element#blockchain_poc_path_element_v2_pb.witnesses.

print(undefined) ->
    <<"type=element undefined">>;
print(#blockchain_poc_path_element_v2_pb{
         challengee=Challengee,
         receipt=Receipt,
         witnesses=Witnesses
        }) ->
    io_lib:format("type=element challengee: ~s, receipt: ~s\n\t\twitnesses: ~s",
                  [
                   ?TO_ANIMAL_NAME(Challengee),
                   blockchain_poc_receipt_v2:print(Receipt),
                   string:join(lists:map(fun(Witness) ->
                                                 blockchain_poc_witness_v2:print(Witness)
                                         end,
                                         Witnesses), "\n\t\t")
                  ]).

%% ------------------------------------------------------------------
%% EUNIT Tests
%% ------------------------------------------------------------------
-ifdef(TEST).

new_test() ->
    Element = #blockchain_poc_path_element_v2_pb{
                 challengee= <<"challengee">>,
                 receipt= undefined,
                 witnesses= []
                },
    ?assertEqual(Element, new(<<"challengee">>, undefined, [])).

challengee_test() ->
    Element = new(<<"challengee">>, undefined, []),
    ?assertEqual(<<"challengee">>, challengee(Element)).

receipt_test() ->
    Element = new(<<"challengee">>, undefined, []),
    ?assertEqual(undefined, receipt(Element)).

witnesses_test() ->
    Element = new(<<"challengee">>, undefined, []),
    ?assertEqual([], witnesses(Element)).

add_receipt_test() ->
    Receipt = blockchain_poc_receipt_v2:new(<<"gateway">>, -110, <<"data">>, radio, 2, 666, 667, 1, 1),
    Element0 = new(<<"challengee">>, undefined, []),
    Element = add_receipt(Element0, Receipt),
    ?assertEqual(Receipt, receipt(Element)).

add_witness_test() ->
    Witness = blockchain_poc_witness_v2:new(<<"gateway">>, -110, <<"hash">>, 2, erlang:system_time(microsecond), 1, 1),
    Element0 = new(<<"challengee">>, undefined, []),
    Element = add_witness(Element0, Witness),

    ?assert(lists:member(Witness, witnesses(Element))).

duplicate_witness_test() ->
    Witness = blockchain_poc_witness_v2:new(<<"gateway">>, -110, <<"hash">>, 2, erlang:system_time(microsecond), 1, 1),
    Element0 = new(<<"challengee">>, undefined, []),
    Element1 = add_witness(Element0, Witness),
    ?assertEqual({error, witness_already_added}, add_witness(Element1, Witness)).

max_witnesses_test() ->
    Witness1 = blockchain_poc_witness_v2:new(<<"gateway1">>, -110, <<"hash">>, 2, erlang:system_time(microsecond), 1, 1),
    Witness2 = blockchain_poc_witness_v2:new(<<"gateway2">>, -110, <<"hash">>, 2, erlang:system_time(microsecond), 1, 1),
    Witness3 = blockchain_poc_witness_v2:new(<<"gateway3">>, -110, <<"hash">>, 2, erlang:system_time(microsecond), 1, 1),
    Witness4 = blockchain_poc_witness_v2:new(<<"gateway4">>, -110, <<"hash">>, 2, erlang:system_time(microsecond), 1, 1),
    Witness5 = blockchain_poc_witness_v2:new(<<"gateway5">>, -110, <<"hash">>, 2, erlang:system_time(microsecond), 1, 1),

    Element0 = new(<<"challengee">>, undefined, []),
    Element1 = add_witness(Element0, Witness1),
    Element2 = add_witness(Element1, Witness2),
    Element3 = add_witness(Element2, Witness3),
    Element4 = add_witness(Element3, Witness4),
    Element5 = add_witness(Element4, Witness5),

    ?assertEqual(5, length(witnesses(Element5))).

max_witnesses_error_test() ->
    Witness1 = blockchain_poc_witness_v2:new(<<"gateway1">>, -110, <<"hash">>, 2, erlang:system_time(microsecond), 1, 1),
    Witness2 = blockchain_poc_witness_v2:new(<<"gateway2">>, -110, <<"hash">>, 2, erlang:system_time(microsecond), 1, 1),
    Witness3 = blockchain_poc_witness_v2:new(<<"gateway3">>, -110, <<"hash">>, 2, erlang:system_time(microsecond), 1, 1),
    Witness4 = blockchain_poc_witness_v2:new(<<"gateway4">>, -110, <<"hash">>, 2, erlang:system_time(microsecond), 1, 1),
    Witness5 = blockchain_poc_witness_v2:new(<<"gateway5">>, -110, <<"hash">>, 2, erlang:system_time(microsecond), 1, 1),
    Witness6 = blockchain_poc_witness_v2:new(<<"gateway6">>, -110, <<"hash">>, 2, erlang:system_time(microsecond), 1, 1),

    Element0 = new(<<"challengee">>, undefined, []),
    Element1 = add_witness(Element0, Witness1),
    Element2 = add_witness(Element1, Witness2),
    Element3 = add_witness(Element2, Witness3),
    Element4 = add_witness(Element3, Witness4),
    Element5 = add_witness(Element4, Witness5),

    ?assertEqual({error, max_witnesses}, add_witness(Element5, Witness6)).

-endif.