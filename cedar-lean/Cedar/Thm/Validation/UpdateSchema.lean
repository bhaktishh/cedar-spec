import Cedar.Validation.RequestEntityValidator
import Cedar.Thm.Validation.Typechecker.Types
import Cedar.Thm.Validation.Validator

namespace Cedar.Thm

open Cedar.Data
open Cedar.Spec
open Cedar.Validation

/-- a schema is well formed if the entity and action type stores are well formed maps,
and any uid present in the action type store is not present in the entity type store.
the last assumption is true of generated schemas, and having it explicitly be a
pre-condition makes proofs a bit easier (i think) (i might be wrong in which case
it is a fairly simple refactor).
-/
def wf_schema (schema : Schema) : Prop :=
Map.WellFormed schema.ets ∧ Map.WellFormed schema.acts
∧ (∀ k ∈ schema.acts, k.ty ∉ schema.ets)

def updateSchemaPreservesEntityTypes (schema newSchema : Schema) :
  wf_schema schema →
  newSchema = updateSchema schema →
  (∀ uid actsEntry, schema.acts.find? uid = some actsEntry →
  ∃ etsEntry, newSchema.ets.find? uid.ty = some etsEntry ∧
  ∀ ancestor ∈ actsEntry.ancestors, ancestor.ty ∈ etsEntry.ancestors)
:= by
  simp only [wf_schema, and_imp]
  intro wfe₀ _ _ h₀ uid actsEntry h₁
  simp only [updateSchema] at h₀
  exists Prod.snd <| updateSchema.makeEntitySchemaEntries uid.ty (schema.acts.mapOnValues actionSchemaEntryToEntityData)
  constructor
  case left =>
    simp only [h₀]
    generalize h₂ : (updateSchema.makeEntitySchemaEntries uid.ty (Map.mapOnValues actionSchemaEntryToEntityData schema.acts)) = etsPair
    have ⟨ety, etsEntry⟩ := etsPair
    simp only
    generalize h₃ : (List.map
          (fun x => updateSchema.makeEntitySchemaEntries x (Map.mapOnValues actionSchemaEntryToEntityData schema.acts))
          (Set.make
              (Set.map (fun x => x.ty) (Map.mapOnValues actionSchemaEntryToEntityData schema.acts).keys).elts).elts) = m₀
    rw [← Map.in_list_iff_find?_some]
    apply Map.mem_append
    have h₄ : uid.ty = ety := by
      simp only [updateSchema.makeEntitySchemaEntries, Prod.mk.injEq] at h₂
      simp only [h₂]
    subst h₄
    right
    have h₄ : uid ∈ (Map.mapOnValues actionSchemaEntryToEntityData schema.acts).keys := by
      rw [Map.keys_mapOnValues]
      have h₅ := Map.find?_mem_toList h₁
      simp only [Map.toList] at h₅
      simp only [Map.in_list_in_keys h₅]
    have h₅ : uid.ty ∈ ((Set.map (fun x => x.ty) (Map.mapOnValues actionSchemaEntryToEntityData schema.acts).keys)) := by
      simp only [Set.map]
      rw [← Set.make_mem]
      simp only [Set.elts, List.mem_map]
      exists uid
    have ⟨h₆, _⟩ := Set.make_mem uid.ty (Set.map (fun x => x.ty) (Map.mapOnValues actionSchemaEntryToEntityData schema.acts).keys).elts
    rw [← Set.in_list_iff_in_set] at h₅
    simp only [h₅, true_implies] at h₆
    rw [← Set.in_list_iff_in_set] at h₆
    generalize h₇ : (fun x => updateSchema.makeEntitySchemaEntries x (Map.mapOnValues actionSchemaEntryToEntityData schema.acts)) = f at *
    generalize h₈ : (Set.make (Set.map (fun x => x.ty) (Map.mapOnValues actionSchemaEntryToEntityData schema.acts).keys).elts) = s at *
    have h₉ := List.mem_map_of_mem f h₆
    rw [h₃] at h₉
    rw [← h₇] at h₉
    simp only at h₉
    rw [h₂] at h₉
    apply Map.mem_list_mem_make
    have h₁₀ : Set.WellFormed s := by
      subst h₈
      simp only [Set.make_wf]
    rw [Set.wf_iff_sorted] at h₁₀
    simp only [List.Sorted] at h₁₀
    subst h₃
    have h₁₂ : List.SortedBy id (List.map Prod.fst (List.map f s.elts)) := by
      simp only [List.map_map]
      subst h₇
      simp only [updateSchema.makeEntitySchemaEntries]
      unfold Function.comp
      simp only [List.map_id']
      exact h₁₀
    apply List.map_sortedBy_id
    exact h₁₂
    exact h₉
    have h₄ : Map.WellFormed (Map.make m₀) := by simp [Map.make_wf m₀]
    apply Map.wf_append wfe₀ h₄
  case right =>
    intro ancestor ain
    simp only [updateSchema.makeEntitySchemaEntries]
    have h₂ := Map.find?_mem_toList h₁
    have h₃ : actionSchemaEntryToEntityData actsEntry ∈ (Map.filter (fun k _ => k.ty == uid.ty)
            (Map.mapOnValues actionSchemaEntryToEntityData schema.acts)).values := by
      simp only [Map.values, Map.filter, List.mem_map]
      exists (uid, actionSchemaEntryToEntityData actsEntry)
      constructor
      rw [List.mem_filter]
      constructor
      simp only [Map.toList] at h₂
      simp only [Map.in_kvs_in_mapOnValues h₂]
      simp only [beq_self_eq_true]
      simp only
    rw [← Set.make_mem, List.mem_join]
    exists (List.map (fun x => x.ty) (actionSchemaEntryToEntityData actsEntry).ancestors.elts)
    simp only [List.mem_map]
    constructor
    exists actionSchemaEntryToEntityData actsEntry
    exists ancestor

def schemaIsWellFormed (schema newSchema : Schema) :
  wf_schema schema →
  wf_schema newSchema →
  newSchema = updateSchema schema →
  newSchema.acts = schema.acts ∧
  ∀ ty etsEntry, newSchema.ets.find? ty = some etsEntry →
  ((schema.ets.find? ty = some etsEntry)
  ∨ ((¬ schema.ets.find? ty = some etsEntry) ∧ (∃ uid actsEntry, uid.ty = ty ∧ schema.acts.find? uid = some actsEntry)))
:= by
  simp [wf_schema, Map.WellFormed, Map.toList]
  intro wfe₀ wfa₀ sch₀ wfe₁ wfa₁ sch₁ h₀
  constructor
  case left =>
    simp only [updateSchema] at h₀
    simp [h₀]
  case right =>
    intro ty etsEntry h₁
    cases h₂ : Map.find? schema.ets ty with
    | none =>
      right
      constructor
      simp only [not_false_eq_true]
      sorry
    | some val => sorry



    -- intro ty etsEntry h₁
    -- simp only [updateSchema] at h₀
    -- generalize h₂ : List.map
    --         (fun x =>
    --           updateSchema.makeEntitySchemaEntries x (Map.mapOnValues actionSchemaEntryToEntityData schema.acts))
    --         (Set.make
    --             (Set.map (fun x => x.ty) (Map.mapOnValues actionSchemaEntryToEntityData schema.acts).keys).elts).elts = f at *
    -- rw [h₀] at h₁
    -- simp only at h₁
    -- cases h₃ : Map.find? schema.ets ty with
    -- | none =>
    --   right
    --   constructor
    --   simp only [not_false_eq_true]

    -- | some ese =>
    --   left
    --   simp only [Option.some.injEq]
    --   sorry
    -- have h₃ := Map.find_append_in_one (Map.kvs schema.ets) f ty etsEntry h₁
    -- cases h₃ with
    -- | inl h₃ =>
    --   left
    --   rw [← wfe₀] at h₃
    --   exact h₃
    -- | inr h₃ =>
    --   right
