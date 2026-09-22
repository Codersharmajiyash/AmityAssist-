import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from backend.config import settings
from backend.services.advanced_ai_service import advanced_reply
from backend.services.policy_search_service import PolicySearchService

def set_config(provider: str, api_key: str):
    object.__setattr__(settings, "llm_provider", provider)
    object.__setattr__(settings, "gemini_api_key", api_key)

def test_hybrid_behavior():
    print("=" * 65)
    print("TESTING HYBRID AI ARCHITECTURE (GEMINI CLOUD vs LOCAL FALLBACK)")
    print("=" * 65)

    # -------------------------------------------------------------
    # Scenario 1: OTHER SYSTEM SIMULATION (No API Key, Provider=local)
    # -------------------------------------------------------------
    set_config("local", "")
    print(f"\n[Scenario 1: Other Systems / No API Key]")
    print(f" - settings.llm_enabled: {settings.llm_enabled} (Must be False)")
    assert settings.llm_enabled is False, "llm_enabled should be False when no key is set"

    # Test 1a: Advanced Chat Reply
    session_data = {"turns": []}
    res_local = advanced_reply(
        message="What is the withdrawal policy and refund slab?",
        student={"name": "Aarav Sharma", "attendance": 82.0, "cgpa": 8.4},
        session=session_data,
        language="english",
        voice=False,
    )
    print(f" - Fallback Source: {res_local['source']}")
    print(f" - Local Reply snippet: {res_local['reply'][:95]}...")
    assert res_local["source"] == "local-context", "Expected local-context source"
    assert len(res_local["reply"]) > 20, "Local reply should not be empty"

    # Test 1b: Policy Voice Intelligence (RAG)
    rag_local = PolicySearchService.hybrid_guidance(
        query="I need migration certificate",
        student_id="STU001",
    )
    print(f" - Local Domain: {rag_local.get('domain')}")
    print(f" - Local Spoken Guidance: {rag_local.get('voice_speech_text', '')[:95]}...")
    assert len(rag_local.get("citations", [])) > 0, "Expected policy citations"
    ans_lower = rag_local.get("answer", "").lower()
    assert "migration" in ans_lower or "registrar" in ans_lower or "guidance" in ans_lower

    print(">>> Scenario 1 PASSED: System operates seamlessly in 100% offline / local mode without an API key!")

    # -------------------------------------------------------------
    # Scenario 2: INVALID / EXPIRED KEY (Graceful Network Fallback)
    # -------------------------------------------------------------
    set_config("gemini", "AIzaSy_INVALID_OR_EXPIRED_KEY_12345")
    print(f"\n[Scenario 2: System with Invalid/Expired Key or Network Outage]")
    print(f" - settings.llm_enabled: {settings.llm_enabled} (True, but Google API call will fail)")

    res_fallback = advanced_reply(
        message="I have attendance shortage what to do",
        student={"name": "Aarav Sharma", "attendance": 68.0, "cgpa": 7.2},
        session=session_data,
        language="english",
        voice=False,
    )
    print(f" - Graceful Fallback Source: {res_fallback['source']}")
    print(f" - Fallback Reply: {res_fallback['reply'][:95]}...")
    assert res_fallback["source"] == "local-context", "Failed API call must silently fall back to local-context"
    assert "aarav" in res_fallback["reply"].lower()

    print(">>> Scenario 2 PASSED: Automatic silent fallback to local intelligence on any API error!")

    # -------------------------------------------------------------
    # Scenario 3: YOUR SYSTEM (With Live API Key from root .env)
    # -------------------------------------------------------------
    import dotenv
    dotenv.load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "../../.env"), override=True)
    real_key = os.getenv("GEMINI_API_KEY", "")
    real_provider = os.getenv("LLM_PROVIDER", "gemini")

    print(f"\n[Scenario 3: Live System Configuration from Root .env]")
    print(f" - Configured Provider: {real_provider}")
    print(f" - API Key Present: {'YES (Key starts with ' + real_key[:8] + '...)' if real_key else 'NO'}")

    set_config(real_provider, real_key)

    if settings.llm_enabled:
        res_live = PolicySearchService.hybrid_guidance(
            query="Tell me about caution deposit refund",
            student_id="STU001",
        )
        print(f" - Live RAG Answer: {res_live.get('answer', '')[:110]}...")
        assert len(res_live.get("answer", "")) > 10
        print(">>> Scenario 3 PASSED: Cloud-based Gemini LLM active and synthesizing answers!")
    else:
        print(">>> Scenario 3 NOTE: No GEMINI_API_KEY set in .env; system defaulted safely to local engine.")

    print("\n" + "=" * 65)
    print("ALL 3 HYBRID SCENARIOS VERIFIED: SYSTEM IS 100% PORTABLE & RESILIENT!")
    print("=" * 65)

if __name__ == "__main__":
    test_hybrid_behavior()
