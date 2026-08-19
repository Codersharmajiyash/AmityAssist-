import logging
from typing import Optional

# Setup mock logging for email service
logger = logging.getLogger("email_service")
logger.setLevel(logging.INFO)
ch = logging.StreamHandler()
ch.setFormatter(logging.Formatter('\n[%(name)s] %(message)s\n'))
if not logger.handlers:
    logger.addHandler(ch)

def send_withdrawal_receipt(student_id: str, student_name: str, reference_id: str):
    """Fired when a student confirms their withdrawal via chat."""
    email_content = f"""
    ================================================================
    MOCK EMAIL SENT TO: {student_id}@uni.edu
    SUBJECT: Receipt of Withdrawal Request [{reference_id}]
    
    Dear {student_name},
    
    This email confirms that we have successfully received your 
    withdrawal request (Reference: {reference_id}).
    
    Our Registrar's Office will review your application and any 
    supporting documents within 2 business days.
    
    You can track the status of your request at any time via the 
    UniAssist portal.
    ================================================================
    """
    logger.info(email_content)

def send_status_update(student_id: str, status: str):
    """Fired when an administrator approves or rejects a request."""
    email_content = f"""
    ================================================================
    MOCK EMAIL SENT TO: {student_id}@uni.edu
    SUBJECT: Update on your Withdrawal Request
    
    Dear Student ({student_id}),
    
    The Registrar's Office has reviewed your withdrawal application.
    Your request status has been updated to: {status.upper()}.
    
    Please log in to the UniAssist portal for further instructions or 
    to view any final steps.
    ================================================================
    """
    logger.info(email_content)
