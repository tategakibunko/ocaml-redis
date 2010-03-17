(* Copyright (C) 2009 Rory Geoghegan - r.geoghegan@gmail.com
   Released under the BSD license. See the LICENSE.txt file for more info.

   Main library file. *)
open Redis_util;;

let create_connection ?addr:(addr="127.0.0.1") ?port:(port=6379) () =
    (* From a string of the address, and a port as an int, gets an input and output file discriptor *)
    Connection.create addr port;;

(* Individual commands *)

(* Connection handling *)
let ping connection =
    (* PING *)
    match send_and_receive_command_safely "PING" connection with
        Status("PONG") -> true |
        _ -> failwith "Did not recognize what I got back";;

let quit connection =
    (* QUIT *)
    Connection.send_text "QUIT" connection;;

let auth password connection =
    (* AUTH *)
    handle_status (send_and_receive_command ("AUTH " ^ password) connection);;

(* Commands operating on string values *)
let set key value connection =
    (* SET *)
    begin
        Connection.send_text_straight (Printf.sprintf "SET %s %d" key (String.length value)) connection;
        Connection.send_text value connection;
        match receive_answer connection with
            Status("OK") -> () |
            Status(x) -> failwith ("Received status(" ^ x ^ ") when setting " ^ key) |
            _ -> failwith "Did not recognize what I got back"
    end;;

let get key connection =
    (* GET *)
    match send_and_receive_command_safely ("GET " ^ key) connection with
        Bulk(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

let getset key new_value connection =
    (* GETSET *)
    Connection.send_text_straight (Printf.sprintf "GETSET %s %d" key (String.length new_value)) connection;
    Connection.send_text new_value connection;
    match receive_answer connection with
        Bulk(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

let mget keys connection = 
    (* MGET *)
    match send_and_receive_command_safely (aggregate_command "MGET" keys) connection with
        Multibulk(l) -> l |
        _ -> failwith "Did not recognize what I got back";;

let setnx key value connection =
    (* SETNX *)
    begin
        Connection.send_text_straight (Printf.sprintf "SETNX %s %d" key (String.length value)) connection;
        Connection.send_text value connection;
        handle_integer (receive_answer connection)
    end;;

let mset key_value_pairs connection =
    (* MSET *)
    let rec flatten list_of_pairs result =
        match list_of_pairs with
            (key, value) :: tail -> flatten tail (key :: value :: result) |
            [] -> result
    in
    handle_status (send_multibulk_command ( "MSET" :: (flatten key_value_pairs [])) connection)

let msetnx key_value_pairs connection =
    (* MSET *)
    let rec flatten list_of_pairs result =
        match list_of_pairs with
            (key, value) :: tail -> flatten tail (key :: value :: result) |
            [] -> result
    in
    handle_integer (send_multibulk_command ( "MSETNX" :: (flatten key_value_pairs [])) connection)

let incr key connection =
    (* INCR *)
    match send_and_receive_command_safely (Printf.sprintf "INCR %s" key) connection with
        Integer(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

let incrby key value connection =
    (* INCR *)
    match send_and_receive_command_safely (Printf.sprintf "INCRBY %s %d" key value) connection with
        Integer(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

let decr key connection =
    (* DECR *)
    match send_and_receive_command_safely (Printf.sprintf "DECR %s" key) connection with
        Integer(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

let decrby key value connection =
    (* DECR *)
    match send_and_receive_command_safely (Printf.sprintf "DECRBY %s %d" key value) connection with
        Integer(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

let exists key connection =
    (* EXISTS *)
    handle_integer (send_and_receive_command ("EXISTS " ^ key) connection)

let del keys connection =
    (* DEL *)
    match send_and_receive_command_safely (aggregate_command "DEL" keys) connection with
        Integer(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

let del_one key connection =
    (* Exactly like "del", except you do not need to provide a list, just one key. Not in spec *)
    handle_integer (send_and_receive_command ("DEL " ^ key) connection);;

let value_type key connection =
    (* TYPE, unfortunately type is an ocaml keyword, so it cannot be used as a function name *)
    match send_and_receive_command_safely ("TYPE " ^ key) connection with
        Status("string") -> RedisString |
        Status("set") -> RedisSet |
        Status("list") -> RedisList |
        Status("none") -> RedisNil |
        _ -> failwith "Did not recognize what I got back";;
    
(* Commands operating on the key space *)

let keys pattern connection =
    (* KEYS *)
    match send_and_receive_command_safely ("KEYS " ^ pattern) connection with
        Bulk(String(x)) -> Str.split (Str.regexp " +") x |
        _ -> failwith "Did not recognize what I got back";;

let randomkey connection =
    (* RANDOMKEY *)
    match send_and_receive_command_safely "RANDOMKEY" connection with
        Status(x) -> x |
        _ -> failwith "Did not recognize what I got back";;
        
let rename oldkey newkey connection =
    (* RENAME *)
    handle_status (send_and_receive_command (Printf.sprintf "RENAME %s %s" oldkey newkey) connection);;

let renamenx oldkey newkey connection =
    (* RENAMENX *)
    handle_integer (send_and_receive_command (Printf.sprintf "RENAMENX %s %s" oldkey newkey) connection);;

let dbsize connection =
    (* DBSIZE *)
    match send_and_receive_command_safely  "DBSIZE" connection with
        Integer(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

let expire key seconds connection =
    (* EXPIRE *)
    handle_integer (send_and_receive_command (Printf.sprintf "EXPIRE %s %d" key seconds) connection);;

let ttl key connection =
    (* TTL *)
    match send_and_receive_command_safely ("TTL " ^ key) connection with
        Integer(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

(* Commands operating on lists *)
let rpush key value connection =
    (* RPUSH *)
    begin
        Connection.send_text_straight (Printf.sprintf "RPUSH %s %d" key (String.length value)) connection;
        Connection.send_text value connection;
        match receive_answer connection with
            Status("OK") -> () |
            Status(x) -> failwith ("Received status(" ^ x ^ ") when setting " ^ key) |
            _ -> failwith "Did not recognize what I got back"
    end;;

let lpush key value connection =
    (* RPUSH *)
    begin
        Connection.send_text_straight (Printf.sprintf "LPUSH %s %d" key (String.length value)) connection;
        Connection.send_text value connection;
        match receive_answer connection with
            Status("OK") -> () |
            Status(x) -> failwith ("Received status(" ^ x ^ ") when setting " ^ key) |
            _ -> failwith "Did not recognize what I got back"
    end;;

let llen key connection =
    (* LLEN *)
    match send_and_receive_command_safely ("LLEN " ^ key) connection with
        Integer(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

let lrange key start stop connection =
    (* LRANGE, please note that the word 'end' is a keyword in ocaml, so it has been replaced by 'stop' *)
    match send_and_receive_command_safely (Printf.sprintf "LRANGE %s %d %d" key start stop) connection with
        Multibulk(l) -> l |
        _ -> failwith "Did not recognize what I got back";;

let ltrim key start stop connection =
    (* LTRIM, please note that the word 'end' is a keyword in ocaml, so it has been replaced by 'stop' *)
    match send_and_receive_command_safely (Printf.sprintf "LTRIM %s %d %d" key start stop) connection with
        Status("OK") -> () |
        _ -> failwith "Did not recognize what I got back";;

let lindex key index connection =
    (* GET *)
    match send_and_receive_command_safely (Printf.sprintf "LINDEX %s %d" key index) connection with
        Bulk(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

let lset key index value connection =
    (* LSET *)
    begin
        Connection.send_text_straight (Printf.sprintf "LSET %s %d %d" key index (String.length value)) connection;
        Connection.send_text value connection;
        handle_status (receive_answer connection)
    end;;

let lrem key count value connection =
    (* LREM *)
    begin
        Connection.send_text_straight (Printf.sprintf "LREM %s %d %d" key count (String.length value)) connection;
        Connection.send_text value connection;
        match receive_answer connection with
            Integer(x) -> x |
            _ -> failwith "Did not recognize what I got back"
    end;;

let lpop key connection =
    (* LPOP *)
    match send_and_receive_command_safely ("LPOP " ^ key) connection with
        Bulk(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

let rpop key connection =
    (* RPOP *)
    match send_and_receive_command_safely ("RPOP " ^ key) connection with
        Bulk(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

let rpoplpush src_key dest_key connection =
    (* RPOPLPUSH *)
    match send_and_receive_command_safely ("RPOPLPUSH " ^ src_key ^ " " ^ dest_key) connection with
        Bulk(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

(* Commands operating on sets *)
let sadd key member connection =
    (* SADD *)
    Connection.send_text_straight (Printf.sprintf "SADD %s %d" key (String.length member)) connection;
    Connection.send_text member connection;
    handle_integer (receive_answer connection)

let srem key member connection =
    (* SREM *)
    begin
        Connection.send_text_straight (Printf.sprintf "SREM %s %d" key (String.length member)) connection;
        Connection.send_text member connection;
        handle_integer (receive_answer connection)
    end;;

let spop key connection =
    (* SPOP *)
    match send_and_receive_command_safely ("SPOP " ^ key) connection with
        Bulk(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

let smove srckey destkey member connection =
    (* SMOVE *)
    begin
        Connection.send_text_straight (Printf.sprintf "SMOVE %s %s %d" srckey destkey (String.length member)) connection;
        Connection.send_text member connection;
        handle_integer (receive_answer connection)
    end;;

let scard key connection =
    (* SCARD *)
    match send_and_receive_command_safely ("SCARD " ^ key) connection with
        Integer(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

let sismember key member connection =
    (* SISMEMBER *)
    begin
        Connection.send_text_straight (Printf.sprintf "SISMEMBER %s %d" key (String.length member)) connection;
        Connection.send_text member connection;
        handle_integer (receive_answer connection)
    end;;

let smembers key connection =
    (* SMEMBERS *)
    match send_and_receive_command_safely ("SMEMBERS " ^ key) connection with
        Multibulk(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

let sinter keys connection =
    (* SINTER *)
    match send_and_receive_command_safely (aggregate_command "SINTER" keys) connection with
        Multibulk(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

let sinterstore dstkey keys connection =
    (* SINTERSTORE *)
    match send_and_receive_command_safely (aggregate_command "SINTERSTORE" (dstkey :: keys)) connection with
        Integer(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

let sunion keys connection =
    (* SUNION *)
    match send_and_receive_command_safely (aggregate_command "SUNION" keys) connection with
        Multibulk(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

let sunionstore dstkey keys connection =
    (* SUNIONSTORE *)
    match send_and_receive_command_safely (aggregate_command "SUNIONSTORE" (dstkey :: keys)) connection with
        Integer(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

let sdiff keys connection =
    (* SDIFF *)
    match send_and_receive_command_safely (aggregate_command "SDIFF" keys) connection with
        Multibulk(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

let sdiffstore dstkey keys connection =
    (* SDIFFSTORE *)
    match send_and_receive_command_safely (aggregate_command "SDIFFSTORE" (dstkey :: keys)) connection with
        Integer(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

let srandmember key connection =
    (* SRANDMEMBER *)
    match send_and_receive_command_safely ("SRANDMEMBER " ^ key) connection with
        Bulk(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

(* Multiple databases handling commands *)
let select index connection =
    (* SELECT *)
    handle_status
        (send_and_receive_command
            ("SELECT " ^
                (string_of_int index))
            connection);;

let move key index connection =
    (* MOVE *)
    handle_integer (send_and_receive_command ( Printf.sprintf "MOVE %s %d" key index ) connection)

let flushdb connection =
    (* FLUSHDB *)
    handle_status (send_and_receive_command "FLUSHDB" connection);;

let flushall connection =
    (* FLUSHALL *)
    handle_status (send_and_receive_command "FLUSHALL" connection);;

(* Commands operating on sorted sets *)
let zadd key score member connection =
    (* ZADD *)
    Connection.send_text (Printf.sprintf "ZADD %s %f %d" key score (String.length member)) connection;
    Connection.send_text member connection;
    handle_integer (receive_answer connection);;

let zrem key member connection =
    (* ZREM *)
    Connection.send_text (Printf.sprintf "ZREM %s %d" key (String.length member)) connection;
    Connection.send_text member connection;
    handle_integer (receive_answer connection);;

let zrange key start stop connection =
    (* ZRANGE, please note that the word 'end' is a keyword in ocaml, so it has been replaced by 'stop' *)
    match send_and_receive_command_safely (Printf.sprintf "ZRANGE %s %d %d" key start stop) connection with
        Multibulk(l) -> l |
        _ -> failwith "Did not recognize what I got back";;

let zrevrange key start stop connection =
    (* ZREVRANGE, please note that the word 'end' is a keyword in ocaml, so it has been replaced by 'stop' *)
    match send_and_receive_command_safely (Printf.sprintf "ZREVRANGE %s %d %d" key start stop) connection with
        Multibulk(l) -> l |
        _ -> failwith "Did not recognize what I got back";;

let zrangebyscore key start stop ?(limit=`Unlimited) connection =
    (* ZRANGEBYSCORE, please note that the word 'end' is a keyword in ocaml, so it has been replaced by 'stop' *)
    let command =
        let limit = match limit with
            `Unlimited -> "" |
            `Limit(x,y) -> (Printf.sprintf " LIMIT %d %d" x y)
        in
        Printf.sprintf "ZRANGEBYSCORE %s %f %f%s" key start stop limit
    in
    match (send_and_receive_command_safely command connection) with
        Multibulk(m) -> m |
        _ -> failwith "Did not recognize what I got back";;

let zincrby key increment member connection =
    (* ZINCRBY *)
    Connection.send_text (Printf.sprintf "ZINCRBY %s %f %d" key increment (String.length member)) connection;
    Connection.send_text member connection;
    handle_float (receive_answer connection);;

let zcard key connection =
    (* ZCARD *)
    match (send_and_receive_command_safely ("ZCARD " ^ key) connection) with
        Integer(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

let zscore key member connection =
    (* ZSCORE *)
    Connection.send_text (Printf.sprintf "ZSCORE %s %d" key (String.length member)) connection;
    Connection.send_text member connection;
    handle_float (receive_answer connection);;

let zremrangebyscore key min max connection =
    (* ZREMRANGEBYSCORE *)
    match send_and_receive_command_safely (Printf.sprintf "ZREMRANGEBYSCORE %s %f %f" key min max) connection with
        Integer(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

(* Sorting *)
let sort key
    ?pattern
    ?(limit=`Unlimited)
    ?get
    ?(order=`Asc)
    ?(alpha=`NonAlpha)
        connection =
    (* SORT *)
    let command = 
        let pattern = match pattern with
            None -> "" |
            Some x -> " BY " ^ x
        in
        let limit = match limit with
            `Unlimited -> "" |
            `Limit(x,y) -> (Printf.sprintf " LIMIT %d %d" x y)
        in
        let get = match get with
            None -> "" |
            Some x -> " GET " ^ x
        in
        let order = match order with
            `Asc -> "" |
            `Desc -> " DESC"
        in
        let alpha = match alpha with
            `NonAlpha -> "" |
            `Alpha -> " ALPHA"
        in
        "SORT " ^ key ^ pattern ^ limit ^ get ^ order ^ alpha
    in match send_and_receive_command_safely command connection with
        Multibulk(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

(* Persistence control commands *)
let save connection =
    (* SAVE *)
    handle_status (send_and_receive_command "SAVE" connection);;

let bgsave connection =
    (* BGSAVE *)
    handle_special_status "Background saving started" (send_and_receive_command "BGSAVE" connection);;

let lastsave connection =
    (* LASTSAVE *)
    match send_and_receive_command_safely "LASTSAVE" connection with
        Integer(x) -> float_of_int x |
        LargeInteger(x) -> x |
        _ -> failwith "Did not recognize what I got back";;

let shutdown connection =
    (* SHUTDOWN *)
    Connection.send_text "SHUTDOWN" connection;
    try
        match receive_answer connection with
            Status(x) -> failwith x | 
            _ -> failwith "Did not recognize what I got back"
    with End_of_file -> ();;

let bgrewriteaof connection =
    (* BGREWRITEAOF *)
    handle_special_status
        "Background append only file rewriting started"
        (send_and_receive_command "BGREWRITEAOF" connection);;

(* Remote server control commands *)

module Info =
    struct
        type t = {fields: string list; values: (string, string) Hashtbl.t;}
        let tokenizer text = 
            let line_spliter line =
                let colon_index = String.index line ':' in
                let key = String.sub line 0 colon_index in
                let value = String.sub line (colon_index + 1) ((String.length line) - 1 -colon_index) in
                    (key, value)
            in
                List.map line_spliter
                    (Str.split (Str.regexp "\r\n") text)
        let create text =
            let values = Hashtbl.create 10
            in
            let loader (key, value) = begin
                    Hashtbl.add values key value;
                    key
                end
            in
            let fields = List.map loader (tokenizer text)
            in
                {fields=fields; values=values}
        let get info field =
            Hashtbl.find info.values field
        let get_fields info =
            info.fields
    end;;
        
let info connection =
    match send_and_receive_command_safely "INFO" connection with
        Bulk(x) -> Info.create (string_of_bulk_data x) |
        _ -> failwith "Did not recognize what I got back";;
