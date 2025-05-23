// @generated by protoc-gen-es v2.2.4 with parameter "keep_empty_files=true,target=js+dts"
// @generated from file examples/proto_grpc/status.proto (package rpc, syntax proto3)
/* eslint-disable */

import type { GenFile, GenMessage } from "@bufbuild/protobuf/codegenv1";
import type { Message } from "@bufbuild/protobuf";
import type { Any } from "@bufbuild/protobuf/wkt";

/**
 * Describes the file examples/proto_grpc/status.proto.
 */
export declare const file_examples_proto_grpc_status: GenFile;

/**
 * @generated from message rpc.Status
 */
export declare type Status = Message<"rpc.Status"> & {
  /**
   * @generated from field: int32 code = 1;
   */
  code: number;

  /**
   * @generated from field: string message = 2;
   */
  message: string;

  /**
   * @generated from field: repeated google.protobuf.Any details = 3;
   */
  details: Any[];
};

/**
 * Describes the message rpc.Status.
 * Use `create(StatusSchema)` to create a new message.
 */
export declare const StatusSchema: GenMessage<Status>;

