; Windows Credential Manager helpers for AutoHotkey v1 (Unicode, 32-bit or 64-bit).

CredentialManager_Write(target_name, username, secret) {
    static CRED_TYPE_GENERIC := 1
    static CRED_PERSIST_LOCAL_MACHINE := 2
    static CRED_MAX_CREDENTIAL_BLOB_SIZE := 2560

    secret_bytes := StrLen(secret) * 2
    if (secret_bytes > CRED_MAX_CREDENTIAL_BLOB_SIZE)
        return false

    VarSetCapacity(target_buffer, (StrLen(target_name) + 1) * 2, 0)
    StrPut(target_name, &target_buffer, StrLen(target_name) + 1, "UTF-16")
    VarSetCapacity(username_buffer, (StrLen(username) + 1) * 2, 0)
    StrPut(username, &username_buffer, StrLen(username) + 1, "UTF-16")
    VarSetCapacity(secret_buffer, secret_bytes + 2, 0)
    StrPut(secret, &secret_buffer, StrLen(secret) + 1, "UTF-16")

    offsets := CredentialManager_CredentialOffsets()
    VarSetCapacity(credential, offsets.size, 0)
    NumPut(CRED_TYPE_GENERIC, credential, 4, "UInt")
    NumPut(&target_buffer, credential, 8, "Ptr")
    NumPut(secret_bytes, credential, offsets.blob_size, "UInt")
    NumPut(&secret_buffer, credential, offsets.blob, "Ptr")
    NumPut(CRED_PERSIST_LOCAL_MACHINE, credential, offsets.persist, "UInt")
    NumPut(&username_buffer, credential, offsets.username, "Ptr")

    return DllCall("Advapi32\CredWriteW", "Ptr", &credential, "UInt", 0, "Int") != 0
}

CredentialManager_Read(target_name) {
    static CRED_TYPE_GENERIC := 1
    credential_ptr := 0
    if !DllCall("Advapi32\CredReadW", "WStr", target_name, "UInt", CRED_TYPE_GENERIC
        , "UInt", 0, "PtrP", credential_ptr, "Int")
        return ""

    result := ""
    try {
        offsets := CredentialManager_CredentialOffsets()
        username_ptr := NumGet(credential_ptr + 0, offsets.username, "Ptr")
        blob_size := NumGet(credential_ptr + 0, offsets.blob_size, "UInt")
        blob_ptr := NumGet(credential_ptr + 0, offsets.blob, "Ptr")

        if (blob_size <= 2560 && Mod(blob_size, 2) = 0) {
            username := username_ptr ? StrGet(username_ptr, "UTF-16") : ""
            secret := (blob_ptr && blob_size) ? StrGet(blob_ptr, Floor(blob_size / 2), "UTF-16") : ""
            result := {username: username, password: secret}
        }
    } catch e {
        result := ""
    }

    DllCall("Advapi32\CredFree", "Ptr", credential_ptr)
    return result
}

CredentialManager_Delete(target_name) {
    static CRED_TYPE_GENERIC := 1
    static ERROR_NOT_FOUND := 1168
    deleted := DllCall("Advapi32\CredDeleteW", "WStr", target_name, "UInt", CRED_TYPE_GENERIC
        , "UInt", 0, "Int")
    return deleted || A_LastError = ERROR_NOT_FOUND
}

CredentialManager_CredentialOffsets() {
    ; CREDENTIALW contains pointer-aligned fields, so these offsets differ by bitness.
    blob_size := 16 + (2 * A_PtrSize)
    blob := blob_size + A_PtrSize
    persist := blob + A_PtrSize
    attributes := persist + 8
    target_alias := attributes + A_PtrSize
    username := target_alias + A_PtrSize
    return {blob_size: blob_size, blob: blob, persist: persist
        , username: username, size: username + A_PtrSize}
}

NightShark_LoadRememberedCredentials(neutron) {
    credential := CredentialManager_Read("NightShark_Standalone_Login")
    return IsObject(credential) ? JSON.Dump(credential) : ""
}

NightShark_LoadRememberedUsername(neutron) {
    credential := CredentialManager_Read("NightShark_Standalone_Login")
    return IsObject(credential) ? credential.username : ""
}

NightShark_SaveRememberedCredentials(neutron, username, password) {
    return CredentialManager_Write("NightShark_Standalone_Login", username, password)
}

NightShark_DeleteRememberedCredentials(neutron) {
    return CredentialManager_Delete("NightShark_Standalone_Login")
}
