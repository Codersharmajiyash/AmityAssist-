import sys
sys.path.insert(0, r'c:\Users\prade\Uniassist\AmityAssist-')

from backend.services.policy_search_service import PolicySearchService
from backend.services.procedure_service import ProcedureService

print("=== 1. TESTING PROCEDURE SERVICE (BESPOKE PROCEDURES) ===")
procs = ProcedureService.list_procedures()
deg_proc = next((p for p in procs if "degree" in p.get("id", "").lower()), None)
if deg_proc:
    print(f" [PASS] Found Procedure: {deg_proc['id']} - {deg_proc['title']}")
    steps = deg_proc.get("steps", [])
    print(f" Total Steps: {len(steps)}")
    for s in steps:
        print(f"   Step {s['step_number']}: {s['title']} ({s['responsible_desk']}) - {s['description'][:70]}...")
else:
    print(" [FAIL] Degree procedure not found in ProcedureService!")

print("\n=== 2. TESTING DIGITAL COUNSELOR / HYBRID GUIDANCE ===")
test_queries = [
    "how to apply for degree certificate",
    "degree fee account details",
    "what is step 4 of degree application",
]

for q in test_queries:
    print(f"\n--- Query: '{q}' ---")
    res = PolicySearchService.hybrid_guidance(query=q, student_id="STU001", language="en-IN")
    ans = res.get("answer", "")
    print("Answer Preview:\n", ans[:300] + ("..." if len(ans) > 300 else ""))
    print("Recommended Action:", res.get("recommended_action"))
    print("Action URL:", res.get("action_url"))
    print("Voice Speech Text:", res.get("voice_speech_text") or res.get("speech_text"))

    # Assertions for main query
    if "how to apply for degree certificate" in q:
        assert "No Dues" in ans, "Missing No Dues requirement!"
        assert "2025" in ans, "Missing 2025 batch requirement!"
        assert "1,100" in ans or "1100" in ans, "Missing Rs 1100 fee!"
        assert "911010033371991" in ans, "Missing Account Number!"
        assert "UTIB0000158" in ans, "Missing IFSC Code!"
        assert "400" in ans, "Missing Rs 400 courier charge!"
        assert "parent" in ans.lower(), "Missing candidate or parent handover rule!"
        assert "email" in ans.lower(), "Missing email acknowledgement requirement!"
        assert "09.%20Degree" in res.get("action_url", ""), "Missing link to Form 09!"
        print(" [PASS] All 7 official degree points and account details verified 100%!")

print("\n=== 3. TESTING HINDI & HINGLISH LOCALIZATION ===")
res_hi = PolicySearchService.hybrid_guidance(query="degree certificate kaise apply karein", student_id="STU001", language="hi-IN")
print("Hindi Answer (Preview):\n", res_hi.get("answer", "")[:200])
assert "911010033371991" in res_hi.get("answer", "")
assert "UTIB0000158" in res_hi.get("answer", "")
print(" [PASS] Hindi degree response verified!")

res_latn = PolicySearchService.hybrid_guidance(query="degree certificate kaise apply karein", student_id="STU001", language="hi-Latn")
print("Hinglish Answer (Preview):\n", res_latn.get("answer", "")[:200])
assert "911010033371991" in res_latn.get("answer", "")
assert "UTIB0000158" in res_latn.get("answer", "")
print(" [PASS] Hinglish degree response verified!")

print("\n=== 4. TESTING MULTI-TURN STEP TARGET ===")
# Test multi-turn step 4 recall
main_res = PolicySearchService.hybrid_guidance(query="how to apply for degree certificate", student_id="STU001", language="en-IN")
history = [
    {"role": "user", "content": "how to apply for degree certificate"},
    {"role": "assistant", "content": main_res.get("answer", "")}
]
res_step4 = PolicySearchService.hybrid_guidance(query="what is step 4 again", student_id="STU001", language="en-IN", history=history)
print("Step 4 recall answer:\n", res_step4.get("answer", ""))
assert "1100" in res_step4.get("answer", "") or "Fee" in res_step4.get("answer", "")
print(" [PASS] Step 4 recall verified!")

print("\nALL DEGREE PROCEDURE VERIFICATION CHECKS PASSED 100%!")
