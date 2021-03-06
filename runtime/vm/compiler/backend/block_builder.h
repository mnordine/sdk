// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#ifndef RUNTIME_VM_COMPILER_BACKEND_BLOCK_BUILDER_H_
#define RUNTIME_VM_COMPILER_BACKEND_BLOCK_BUILDER_H_

#include "vm/compiler/backend/flow_graph.h"
#include "vm/compiler/backend/il.h"

namespace dart {
namespace compiler {

// Helper class for building basic blocks in SSA form.
class BlockBuilder : public ValueObject {
 public:
  BlockBuilder(FlowGraph* flow_graph, BlockEntryInstr* entry)
      : flow_graph_(flow_graph),
        entry_(entry),
        current_(entry),
        dummy_env_(
            new Environment(0, 0, flow_graph->parsed_function(), nullptr)) {}

  Definition* AddToInitialDefinitions(Definition* def) {
    def->set_ssa_temp_index(flow_graph_->alloc_ssa_temp_index());
    auto normal_entry = flow_graph_->graph_entry()->normal_entry();
    flow_graph_->AddToInitialDefinitions(normal_entry, def);
    return def;
  }

  template <typename T>
  T* AddDefinition(T* def) {
    def->set_ssa_temp_index(flow_graph_->alloc_ssa_temp_index());
    AddInstruction(def);
    return def;
  }

  template <typename T>
  T* AddInstruction(T* instr) {
    if (instr->ComputeCanDeoptimize()) {
      // All instructions that can deoptimize must have an environment attached
      // to them.
      instr->SetEnvironment(dummy_env_);
    }
    current_ = current_->AppendInstruction(instr);
    return instr;
  }

  void AddReturn(Value* value) {
    ReturnInstr* instr = new ReturnInstr(
        TokenPos(), value, CompilerState::Current().GetNextDeoptId());
    AddInstruction(instr);
    entry_->set_last_instruction(instr);
  }

  Definition* AddParameter(intptr_t index, bool with_frame) {
    return AddToInitialDefinitions(new ParameterInstr(
        index, flow_graph_->graph_entry(), with_frame ? FPREG : SPREG));
  }

  TokenPosition TokenPos() { return flow_graph_->function().token_pos(); }

  Definition* AddNullDefinition() {
    return flow_graph_->GetConstant(Object::ZoneHandle());
  }

  Definition* AddUnboxInstr(Representation rep, Value* value, bool is_checked) {
    Definition* unboxed_value =
        AddDefinition(UnboxInstr::Create(rep, value, DeoptId::kNone));
    if (is_checked) {
      // The type of |value| has already been checked and it is safe to
      // adjust reaching type. This is done manually because there is no type
      // propagation when building intrinsics.
      unboxed_value->AsUnbox()->value()->SetReachingType(
          new CompileType(CompileType::FromCid(CidForRepresentation(rep))));
    }
    return unboxed_value;
  }

  Definition* AddUnboxInstr(Representation rep,
                            Definition* boxed,
                            bool is_checked) {
    return AddUnboxInstr(rep, new Value(boxed), is_checked);
  }

  BranchInstr* AddBranch(ComparisonInstr* comp,
                         TargetEntryInstr* true_successor,
                         TargetEntryInstr* false_successor) {
    auto branch =
        new BranchInstr(comp, CompilerState::Current().GetNextDeoptId());
    current_->AppendInstruction(branch);
    current_ = nullptr;

    *branch->true_successor_address() = true_successor;
    *branch->false_successor_address() = false_successor;

    return branch;
  }

  void AddPhi(PhiInstr* phi) {
    phi->set_ssa_temp_index(flow_graph_->alloc_ssa_temp_index());
    phi->mark_alive();
    entry_->AsJoinEntry()->InsertPhi(phi);
  }

 private:
  static intptr_t CidForRepresentation(Representation rep) {
    switch (rep) {
      case kUnboxedDouble:
        return kDoubleCid;
      case kUnboxedFloat32x4:
        return kFloat32x4Cid;
      case kUnboxedInt32x4:
        return kInt32x4Cid;
      case kUnboxedFloat64x2:
        return kFloat64x2Cid;
      case kUnboxedUint32:
        return kDynamicCid;  // smi or mint.
      default:
        UNREACHABLE();
        return kIllegalCid;
    }
  }

  FlowGraph* flow_graph_;
  BlockEntryInstr* entry_;
  Instruction* current_;
  Environment* dummy_env_;
};

}  // namespace compiler
}  // namespace dart

#endif  // RUNTIME_VM_COMPILER_BACKEND_BLOCK_BUILDER_H_
