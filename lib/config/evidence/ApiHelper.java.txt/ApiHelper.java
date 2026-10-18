package com.sibyl.app.http;

import android.text.TextUtils;
import com.blankj.utilcode.util.SPUtils;
import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.sibyl.app.model.DeviceBean;
import com.sibyl.app.model.FaqListVO;
import com.sibyl.app.model.FeedbackBean;
import io.reactivex.Observable;
import io.reactivex.ObservableEmitter;
import io.reactivex.ObservableOnSubscribe;
import io.reactivex.ObservableSource;
import io.reactivex.Observer;
import io.reactivex.android.schedulers.AndroidSchedulers;
import io.reactivex.functions.Function;
import io.reactivex.schedulers.Schedulers;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.UUID;
import okhttp3.MediaType;
import okhttp3.MultipartBody;
import okhttp3.RequestBody;
import okhttp3.ResponseBody;
import org.json.JSONException;
import org.json.JSONObject;

/* loaded from: /root/.hermes/profiles/bot3/workspaces/sibyl-bluetooth/static_recovered/classes3.dex */
public class ApiHelper {
    private static final String BASE_URL = "https://sibyl.linkcos.cn";
    private static ApiHelper instance;
    private ApiServer service = (ApiServer) BaseRetrofit.INSTANCE.createService(BASE_URL, ApiServer.class);

    public static ApiHelper getInstance() {
        if (instance == null) {
            synchronized (ApiHelper.class) {
                if (instance == null) {
                    instance = new ApiHelper();
                }
            }
        }
        return instance;
    }

    private ApiHelper() {
    }

    private RequestBody getRequestBody(String str) {
        if (TextUtils.isEmpty(str)) {
            return null;
        }
        return RequestBody.create(str, MediaType.parse("application/json; charset=utf-8"));
    }

    public void uploadDevice(DeviceBean deviceBean, Observer<JsonObject> observer) {
        this.service.uploadDevice(FormDataBodyUtil.createJSONBody(deviceBean.toJSON())).subscribeOn(Schedulers.io()).observeOn(AndroidSchedulers.mainThread()).subscribe((Observer<? super JsonObject>) observer);
    }

    public void getUserProtocol(Observer<BaseResult<JsonObject>> observer) {
        this.service.userProtocol().subscribeOn(Schedulers.io()).observeOn(AndroidSchedulers.mainThread()).subscribe(observer);
    }

    public void allDeviceList(Observer<BaseResult<ArrayList<ProductTypeBean>>> observer) {
        this.service.allDeviceList().subscribeOn(Schedulers.io()).observeOn(AndroidSchedulers.mainThread()).subscribe(observer);
    }

    public void requestFunControlPanel(DeviceBean deviceBean, Observer<BaseResult<String>> observer) {
        this.service.requestFuncPanel(deviceBean.getVendorId(), deviceBean.getFlageId(), deviceBean.getFirmwareVersion(), "1.26.38", "Android").subscribeOn(Schedulers.io()).observeOn(AndroidSchedulers.mainThread()).subscribe(observer);
    }

    public void visitorLogin(Observer<BaseResult<LoginBean>> observer) {
        JSONObject jSONObject = new JSONObject();
        try {
            jSONObject.put("uuid", SPUtils.getInstance().getString("phoneUUID", UUID.randomUUID().toString()));
            this.service.visitorLogin(FormDataBodyUtil.createJSONBody(jSONObject.toString())).subscribeOn(Schedulers.io()).observeOn(AndroidSchedulers.mainThread()).subscribe(observer);
        } catch (JSONException e) {
            throw new RuntimeException(e);
        }
    }

    public void getFAQList(Observer<HttpResult<FaqListVO>> observer) {
        this.service.getFaqList().subscribeOn(Schedulers.io()).observeOn(AndroidSchedulers.mainThread()).subscribe(observer);
    }

    public void getGuideList(int i, Observer<BaseResult<ArrayList<GuideBean>>> observer) {
        JSONObject jSONObject = new JSONObject();
        try {
            jSONObject.put("vendorId", i);
            jSONObject.put("vendorIdHex", String.format("%04x", Integer.valueOf(i)).toUpperCase());
            jSONObject.put("flageId", 4809);
            jSONObject.put("flageIdHex", "12C9");
            this.service.getGuideList(FormDataBodyUtil.createJSONBody(jSONObject.toString())).subscribeOn(Schedulers.io()).observeOn(AndroidSchedulers.mainThread()).subscribe(observer);
        } catch (JSONException e) {
            throw new RuntimeException(e);
        }
    }

    public void getOTAInfo(DeviceBean deviceBean, Observer<BaseResult<OTAResultBean>> observer) {
        this.service.checkOTAInfo(deviceBean.getVendorId(), deviceBean.getFlageId(), deviceBean.getFirmwareVersion(), 0).subscribeOn(Schedulers.io()).observeOn(AndroidSchedulers.mainThread()).subscribe(observer);
    }

    public void submitFeedback(FeedbackBean feedbackBean, Observer<JsonObject> observer) {
        this.service.submitFeedback(FormDataBodyUtil.createJSONBody(new Gson().toJson(feedbackBean))).subscribeOn(Schedulers.io()).observeOn(AndroidSchedulers.mainThread()).subscribe((Observer<? super JsonObject>) observer);
    }

    public void uploadImages(ArrayList<String> arrayList, Observer<HttpResult<JsonObject>> observer) {
        this.service.uploadFile(getFileRequestBody((String[]) arrayList.toArray(new String[0]))).subscribeOn(Schedulers.io()).observeOn(AndroidSchedulers.mainThread()).subscribe(observer);
    }

    public void downloadFile(String str, final String str2, final String str3, Observer<DownloadInfo> observer) {
        final DownloadInfo downloadInfo = new DownloadInfo();
        ((DownloadApi) BaseRetrofit.INSTANCE.createService2(BASE_URL, DownloadApi.class)).download(str).subscribeOn(Schedulers.io()).unsubscribeOn(Schedulers.io()).flatMap(new Function<ResponseBody, ObservableSource<DownloadInfo>>() { // from class: com.sibyl.app.http.ApiHelper.1
            @Override // io.reactivex.functions.Function
            public ObservableSource<DownloadInfo> apply(final ResponseBody responseBody) throws Exception {
                return Observable.create(new ObservableOnSubscribe<DownloadInfo>() { // from class: com.sibyl.app.http.ApiHelper.1.1
                    @Override // io.reactivex.ObservableOnSubscribe
                    public void subscribe(ObservableEmitter<DownloadInfo> observableEmitter) throws Exception {
                        Throwable th;
                        InputStream inputStream;
                        byte[] bArr;
                        long contentLength;
                        File file;
                        FileOutputStream fileOutputStream;
                        FileOutputStream fileOutputStream2 = null;
                        try {
                            try {
                                try {
                                    bArr = new byte[8192];
                                    contentLength = responseBody.contentLength();
                                    inputStream = responseBody.byteStream();
                                    try {
                                        file = new File(str2, str3);
                                        downloadInfo.setFile(file);
                                        downloadInfo.setFileSize(contentLength);
                                        File file2 = new File(str2);
                                        if (!file2.exists()) {
                                            file2.mkdirs();
                                        }
                                        fileOutputStream = new FileOutputStream(file);
                                    } catch (Exception e) {
                                        e = e;
                                    }
                                } catch (Exception e2) {
                                    e2.printStackTrace();
                                    return;
                                }
                            } catch (Exception e3) {
                                e = e3;
                                inputStream = null;
                            } catch (Throwable th2) {
                                th = th2;
                                inputStream = null;
                            }
                        } catch (Throwable th3) {
                            th = th3;
                        }
                        try {
                            long currentTimeMillis = System.currentTimeMillis();
                            int i = -1;
                            int i2 = -1;
                            long j = 0;
                            while (true) {
                                int read = inputStream.read(bArr);
                                if (read == i) {
                                    break;
                                }
                                fileOutputStream.write(bArr, 0, read);
                                j += read;
                                int i3 = (int) ((100 * j) / contentLength);
                                long currentTimeMillis2 = (System.currentTimeMillis() - currentTimeMillis) / 1000;
                                if (currentTimeMillis2 == 0) {
                                    currentTimeMillis2 = 1;
                                }
                                long j2 = contentLength;
                                long j3 = j / currentTimeMillis2;
                                if (i3 != i2) {
                                    downloadInfo.setSpeed(j3);
                                    downloadInfo.setProgress(i3);
                                    downloadInfo.setCurrentSize(j);
                                    observableEmitter.onNext(downloadInfo);
                                }
                                i2 = i3;
                                contentLength = j2;
                                i = -1;
                            }
                            fileOutputStream.flush();
                            downloadInfo.setFile(file);
                            observableEmitter.onComplete();
                            fileOutputStream.close();
                            if (inputStream != null) {
                                inputStream.close();
                            }
                        } catch (Exception e4) {
                            e = e4;
                            fileOutputStream2 = fileOutputStream;
                            downloadInfo.setErrorMsg(e);
                            observableEmitter.onError(e);
                            if (fileOutputStream2 != null) {
                                fileOutputStream2.close();
                            }
                            if (inputStream != null) {
                                inputStream.close();
                            }
                        } catch (Throwable th4) {
                            th = th4;
                            fileOutputStream2 = fileOutputStream;
                            if (fileOutputStream2 != null) {
                                try {
                                    fileOutputStream2.close();
                                } catch (Exception e5) {
                                    e5.printStackTrace();
                                    throw th;
                                }
                            }
                            if (inputStream != null) {
                                inputStream.close();
                                throw th;
                            }
                            throw th;
                        }
                    }
                });
            }
        }).observeOn(AndroidSchedulers.mainThread()).subscribe(observer);
    }

    private static MultipartBody getFileRequestBody(String... strArr) {
        MultipartBody.Builder builder = new MultipartBody.Builder();
        for (String str : strArr) {
            File file = new File(str);
            builder.addFormDataPart("file", file.getName(), RequestBody.create(MediaType.parse("multipart/form-data"), file));
        }
        return builder.build();
    }
}
