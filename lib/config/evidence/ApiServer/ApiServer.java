package com.sibyl.app.http;

import com.google.gson.JsonObject;
import com.sibyl.app.model.FaqListVO;
import io.reactivex.Observable;
import java.util.ArrayList;
import okhttp3.MultipartBody;
import okhttp3.RequestBody;
import retrofit2.http.Body;
import retrofit2.http.GET;
import retrofit2.http.POST;
import retrofit2.http.Query;

/* loaded from: /root/.hermes/profiles/bot3/workspaces/sibyl-bluetooth/static_recovered/classes3.dex */
public interface ApiServer {
    @GET("app/promodel/list")
    Observable<BaseResult<ArrayList<ProductTypeBean>>> allDeviceList();

    @GET("app/ota/verify")
    Observable<BaseResult<OTAResultBean>> checkOTAInfo(@Query("vendorId") int i, @Query("flageId") int i2, @Query("localVersion") String str, @Query("proColorId") int i3);

    @GET("app/ota/verify_dev2")
    Observable<BaseResult<OTAResultBean>> checkOTAInfo_dev(@Query("vendorId") int i, @Query("flageId") int i2, @Query("localVersion") String str, @Query("proColorId") int i3);

    @GET("discover/faqList")
    Observable<HttpResult<FaqListVO>> getFaqList();

    @POST("app/guide/list")
    Observable<BaseResult<ArrayList<GuideBean>>> getGuideList(@Body RequestBody requestBody);

    @GET("app/func/controlpanel")
    Observable<BaseResult<String>> requestFuncPanel(@Query("vendorId") int i, @Query("flageId") int i2, @Query("firmwareVersion") String str, @Query("appVersion") String str2, @Query("sys_") String str3);

    @POST("discover/submitFeedback")
    Observable<JsonObject> submitFeedback(@Body RequestBody requestBody);

    @POST("device/bind")
    Observable<JsonObject> uploadDevice(@Body RequestBody requestBody);

    @POST("discover/upload")
    Observable<HttpResult<JsonObject>> uploadFile(@Body MultipartBody multipartBody);

    @GET("/user/protocol")
    Observable<BaseResult<JsonObject>> userProtocol();

    @POST("user/thirdParty/visitorLogin")
    Observable<BaseResult<LoginBean>> visitorLogin(@Body RequestBody requestBody);
}
