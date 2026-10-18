package com.sibyl.app.model;

import java.util.ArrayList;
import java.util.Iterator;

/* loaded from: /root/.hermes/profiles/bot3/workspaces/sibyl-bluetooth/static_recovered/classes3.dex */
public class ControlitemEarbudsKey extends ControlBaseItem {
    private ArrayList<SetInfo> KeyList;

    public static class FuncItem {
        public int cmd;
        public String name;
    }

    public static class SetInfo {
        public ArrayList<SideInfo> event;
        public String icon;
        public String name;
        public String popIcon;
    }

    public ArrayList<SetInfo> getKeyList() {
        return this.KeyList;
    }

    public void setKeyList(ArrayList<SetInfo> arrayList) {
        this.KeyList = arrayList;
    }

    public static class SideInfo {
        public int defaultFun;
        public int eventID;
        private String eventName;
        public ArrayList<FuncItem> list;

        public String getName() {
            return this.eventName;
        }

        public FuncItem getFuncItem(int i) {
            ArrayList<FuncItem> arrayList = this.list;
            if (arrayList == null) {
                return null;
            }
            Iterator<FuncItem> it = arrayList.iterator();
            while (it.hasNext()) {
                FuncItem next = it.next();
                if (next.cmd == i) {
                    return next;
                }
            }
            return null;
        }
    }
}
