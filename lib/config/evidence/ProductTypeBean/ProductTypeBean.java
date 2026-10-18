package com.sibyl.app.http;

import com.sibyl.app.model.DeviceBean;
import java.util.ArrayList;
import okhttp3.HttpUrl;

/* loaded from: /root/.hermes/profiles/bot3/workspaces/sibyl-bluetooth/static_recovered/classes3.dex */
public class ProductTypeBean {
    private ArrayList<DeviceBean> earbudsList;
    private int proType;
    private String typeName;

    public int getProType() {
        return this.proType;
    }

    public void setProType(int i) {
        this.proType = i;
    }

    public String getTypeName() {
        String str = this.typeName;
        return str == null ? HttpUrl.FRAGMENT_ENCODE_SET : str;
    }

    public void setTypeName(String str) {
        this.typeName = str;
    }

    public ArrayList<DeviceBean> getEarbudsList() {
        ArrayList<DeviceBean> arrayList = this.earbudsList;
        return arrayList == null ? new ArrayList<>() : arrayList;
    }

    public void setEarbudsList(ArrayList<DeviceBean> arrayList) {
        this.earbudsList = arrayList;
    }
}
