from ai_ready_demo.security import mask_pii, is_role_allowed


def test_mask_pii_masks_ec_id_and_email():
    text = "Cliente 1712345678 correo carlos.synthetic@example.com"
    masked = mask_pii(text)
    assert "1712345678" not in masked
    assert "carlos.synthetic@example.com" not in masked


def test_internal_doc_not_allowed_for_cliente():
    metadata = {"confidentiality": "internal", "allowed_roles": ["asesor", "supervisor"]}
    assert not is_role_allowed(metadata, "cliente")
    assert is_role_allowed(metadata, "asesor")
