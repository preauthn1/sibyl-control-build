package com.sibyl.app.model;

import java.util.ArrayList;
import java.util.Iterator;
import okhttp3.HttpUrl;

/* loaded from: /root/.hermes/profiles/bot3/workspaces/sibyl-bluetooth/static_recovered/classes3.dex */
public class ControlItemBtnKey extends ControlBaseItem {
    private String leftImg;
    private String leftName;
    private SetInfo music;
    private String rightImg;
    private String rightName;
    private MustAbb tabBsk;

    public static class FuncItem {
        public int cmd;
        public String name;
    }

    public static class MustAbb {
        public int cmd;
        public String title;
    }

    public static class SetInfo {
        public ArrayList<EventItem> event;
        public String name;
    }

    public String getLeftImg() {
        return this.leftImg;
    }

    public String getRightImg() {
        return this.rightImg;
    }

    public String getLeftName() {
        return this.leftName;
    }

    public String getRightName() {
        return this.rightName;
    }

    public MustAbb getTabBsk() {
        return this.tabBsk;
    }

    public SetInfo getMusic() {
        return this.music;
    }

    public static class EventItem {
        public BtnSideInfo left;
        private String leftTitle;
        private String name;
        public BtnSideInfo right;
        private String rightTitle;

        public String getName() {
            String str = this.name;
            return str == null ? HttpUrl.FRAGMENT_ENCODE_SET : str;
        }
    }

    public static class BtnSideInfo {
        public int defaultFun;
        public int eventID;
        public ArrayList<FuncItem> list;
        private String name;

        public String getName() {
            return this.name;
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
