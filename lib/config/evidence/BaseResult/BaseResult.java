package com.sibyl.app.http;

import okhttp3.HttpUrl;

/* loaded from: /root/.hermes/profiles/bot3/workspaces/sibyl-bluetooth/static_recovered/classes3.dex */
public class BaseResult<T> {
    private int code;
    private T data;
    private String msg;
    private boolean success;

    public int getCode() {
        return this.code;
    }

    public void setCode(int i) {
        this.code = i;
    }

    public String getMsg() {
        String str = this.msg;
        return str == null ? HttpUrl.FRAGMENT_ENCODE_SET : str;
    }

    public void setMsg(String str) {
        this.msg = str;
    }

    public T getContent() {
        return this.data;
    }

    public void setContent(T t) {
        this.data = t;
    }

    public boolean isSuccess() {
        return this.success;
    }

    public void setSuccess(boolean z) {
        this.success = z;
    }
}
