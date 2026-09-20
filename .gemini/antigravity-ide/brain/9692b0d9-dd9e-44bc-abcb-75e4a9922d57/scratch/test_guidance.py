from backend.services.policy_search_service import PolicySearchService

res1 = PolicySearchService.hybrid_guidance("what should I do after getting migration certificate form")
print("MIGRATION TEST:", res1["domain"], "|", res1["recommended_action"], "|", res1["citations"][0]["clause_code"])
print("ANSWER PREVIEW:\n", res1["answer"][:180])

res2 = PolicySearchService.hybrid_guidance("what should i do after getting rechecking form")
print("\nRECHECKING TEST:", res2["domain"], "|", res2["recommended_action"])

res3 = PolicySearchService.hybrid_guidance("where can you take me")
print("\nPORTALS TEST:", res3["domain"], "|", res3["action_url"])

res4 = PolicySearchService.hybrid_guidance("can you take me to the withdrawal form")
print("\nWITHDRAWAL NAV TEST:", res4["domain"], "|", res4["action_url"])
