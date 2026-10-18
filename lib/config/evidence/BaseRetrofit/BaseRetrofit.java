package com.sibyl.app.http;

import android.os.Build;
import android.text.TextUtils;
import com.sibyl.app.ext.SPExtKt;
import com.sibyl.app.http.BaseRetrofit;
import com.sibyl.app.http.callback.CrashCallBack;
import java.io.IOException;
import java.nio.charset.Charset;
import java.util.Locale;
import java.util.concurrent.TimeUnit;
import javax.net.ssl.HostnameVerifier;
import kotlin.Lazy;
import kotlin.LazyKt;
import kotlin.Metadata;
import kotlin.jvm.functions.Function0;
import kotlin.jvm.internal.Intrinsics;
import okhttp3.Headers;
import okhttp3.HttpUrl;
import okhttp3.Interceptor;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import okhttp3.ResponseBody;
import okio.Buffer;
import retrofit2.Retrofit;
import retrofit2.adapter.rxjava2.RxJava2CallAdapterFactory;
import retrofit2.converter.gson.GsonConverterFactory;

/* compiled from: BaseRetrofit.kt */
@Metadata(d1 = {"\u0000T\n\u0002\u0018\u0002\n\u0002\u0010\u0000\n\u0002\b\u0003\n\u0002\u0018\u0002\n\u0002\b\u0005\n\u0002\u0018\u0002\n\u0002\b\t\n\u0002\u0010\u000e\n\u0000\n\u0002\u0018\u0002\n\u0002\b\u0005\n\u0002\u0010\u0002\n\u0000\n\u0002\u0018\u0002\n\u0000\n\u0002\u0010\u000b\n\u0000\n\u0002\u0018\u0002\n\u0002\b\u0002\n\u0002\u0018\u0002\n\u0002\b\u0002\n\u0002\u0018\u0002\n\u0002\b\u0002\bÆ\u0002\u0018\u00002\u00020\u0001:\u0001*B\t\b\u0002¢\u0006\u0004\b\u0002\u0010\u0003J'\u0010\u0012\u001a\u0002H\u0013\"\u0004\b\u0000\u0010\u00132\u0006\u0010\u0014\u001a\u00020\u00152\f\u0010\u0016\u001a\b\u0012\u0004\u0012\u0002H\u00130\u0017¢\u0006\u0002\u0010\u0018J'\u0010\u0019\u001a\u0002H\u0013\"\u0004\b\u0000\u0010\u00132\u0006\u0010\u0014\u001a\u00020\u00152\f\u0010\u0016\u001a\b\u0012\u0004\u0012\u0002H\u00130\u0017¢\u0006\u0002\u0010\u0018J\b\u0010\u001a\u001a\u00020\u000bH\u0002J\b\u0010\u001b\u001a\u00020\u000bH\u0002J\u0010\u0010\u001c\u001a\u00020\u001d2\u0006\u0010\u001e\u001a\u00020\u001fH\u0002J\u0010\u0010 \u001a\u00020!2\u0006\u0010\"\u001a\u00020#H\u0002J\u0012\u0010$\u001a\u0004\u0018\u00010\u00152\u0006\u0010\u001e\u001a\u00020\u001fH\u0002J\u001a\u0010%\u001a\u00020&2\u0006\u0010'\u001a\u00020&2\b\u0010(\u001a\u0004\u0018\u00010)H\u0002R\u001b\u0010\u0004\u001a\u00020\u00058BX\u0082\u0084\u0002¢\u0006\f\n\u0004\b\b\u0010\t\u001a\u0004\b\u0006\u0010\u0007R\u001b\u0010\n\u001a\u00020\u000b8BX\u0082\u0084\u0002¢\u0006\f\n\u0004\b\u000e\u0010\t\u001a\u0004\b\f\u0010\rR\u001b\u0010\u000f\u001a\u00020\u000b8BX\u0082\u0084\u0002¢\u0006\f\n\u0004\b\u0011\u0010\t\u001a\u0004\b\u0010\u0010\r¨\u0006+"}, d2 = {"Lcom/sibyl/app/http/BaseRetrofit;", HttpUrl.FRAGMENT_ENCODE_SET, "<init>", "()V", "mTokenInterceptor", "Lokhttp3/Interceptor;", "getMTokenInterceptor", "()Lokhttp3/Interceptor;", "mTokenInterceptor$delegate", "Lkotlin/Lazy;", "mClient", "Lokhttp3/OkHttpClient;", "getMClient", "()Lokhttp3/OkHttpClient;", "mClient$delegate", "mClient2", "getMClient2", "mClient2$delegate", "createService", "T", "baseUrl", HttpUrl.FRAGMENT_ENCODE_SET, "clazz", "Ljava/lang/Class;", "(Ljava/lang/String;Ljava/lang/Class;)Ljava/lang/Object;", "createService2", "newClient", "newClient2", "logRequest", HttpUrl.FRAGMENT_ENCODE_SET, "request", "Lokhttp3/Request;", "isText", HttpUrl.FRAGMENT_ENCODE_SET, "mediaType", "Lokhttp3/MediaType;", "bodyToString", "logResponse", "Lokhttp3/Response;", "response", "crashCallBack", "Lcom/sibyl/app/http/callback/CrashCallBack;", "TokenInterceptor", "app_release"}, k = 1, mv = {2, 2, 0}, xi = 48)
/* loaded from: /root/.hermes/profiles/bot3/workspaces/sibyl-bluetooth/static_recovered/classes3.dex */
public final class BaseRetrofit {
    public static final BaseRetrofit INSTANCE = new BaseRetrofit();

    /* renamed from: mTokenInterceptor$delegate, reason: from kotlin metadata */
    private static final Lazy mTokenInterceptor = LazyKt.lazy(new Function0() { // from class: com.sibyl.app.http.BaseRetrofit$$ExternalSyntheticLambda0
        @Override // kotlin.jvm.functions.Function0
        public final Object invoke() {
            BaseRetrofit.TokenInterceptor mTokenInterceptor_delegate$lambda$0;
            mTokenInterceptor_delegate$lambda$0 = BaseRetrofit.mTokenInterceptor_delegate$lambda$0();
            return mTokenInterceptor_delegate$lambda$0;
        }
    });

    /* renamed from: mClient$delegate, reason: from kotlin metadata */
    private static final Lazy mClient = LazyKt.lazy(new Function0() { // from class: com.sibyl.app.http.BaseRetrofit$$ExternalSyntheticLambda1
        @Override // kotlin.jvm.functions.Function0
        public final Object invoke() {
            OkHttpClient mClient_delegate$lambda$1;
            mClient_delegate$lambda$1 = BaseRetrofit.mClient_delegate$lambda$1();
            return mClient_delegate$lambda$1;
        }
    });

    /* renamed from: mClient2$delegate, reason: from kotlin metadata */
    private static final Lazy mClient2 = LazyKt.lazy(new Function0() { // from class: com.sibyl.app.http.BaseRetrofit$$ExternalSyntheticLambda2
        @Override // kotlin.jvm.functions.Function0
        public final Object invoke() {
            OkHttpClient mClient2_delegate$lambda$2;
            mClient2_delegate$lambda$2 = BaseRetrofit.mClient2_delegate$lambda$2();
            return mClient2_delegate$lambda$2;
        }
    });

    private BaseRetrofit() {
    }

    private final Interceptor getMTokenInterceptor() {
        return (Interceptor) mTokenInterceptor.getValue();
    }

    /* JADX INFO: Access modifiers changed from: private */
    public static final TokenInterceptor mTokenInterceptor_delegate$lambda$0() {
        return new TokenInterceptor();
    }

    private final OkHttpClient getMClient() {
        return (OkHttpClient) mClient.getValue();
    }

    /* JADX INFO: Access modifiers changed from: private */
    public static final OkHttpClient mClient_delegate$lambda$1() {
        return INSTANCE.newClient();
    }

    private final OkHttpClient getMClient2() {
        return (OkHttpClient) mClient2.getValue();
    }

    /* JADX INFO: Access modifiers changed from: private */
    public static final OkHttpClient mClient2_delegate$lambda$2() {
        return INSTANCE.newClient2();
    }

    public final <T> T createService(String baseUrl, Class<T> clazz) {
        Intrinsics.checkNotNullParameter(baseUrl, "baseUrl");
        Intrinsics.checkNotNullParameter(clazz, "clazz");
        return (T) new Retrofit.Builder().baseUrl(baseUrl).client(getMClient()).addConverterFactory(GsonConverterFactory.create()).addCallAdapterFactory(RxJava2CallAdapterFactory.create()).build().create(clazz);
    }

    public final <T> T createService2(String baseUrl, Class<T> clazz) {
        Intrinsics.checkNotNullParameter(baseUrl, "baseUrl");
        Intrinsics.checkNotNullParameter(clazz, "clazz");
        return (T) new Retrofit.Builder().baseUrl(baseUrl).client(getMClient2()).addConverterFactory(GsonConverterFactory.create()).addCallAdapterFactory(RxJava2CallAdapterFactory.create()).build().create(clazz);
    }

    private final OkHttpClient newClient() {
        OkHttpClient.Builder builder = new OkHttpClient.Builder();
        builder.connectTimeout(30L, TimeUnit.SECONDS);
        builder.readTimeout(10L, TimeUnit.SECONDS);
        builder.writeTimeout(10L, TimeUnit.SECONDS);
        builder.addInterceptor(INSTANCE.getMTokenInterceptor());
        HostnameVerifier createInsecureHostnameVerifier = HttpSSLUtils.createInsecureHostnameVerifier();
        Intrinsics.checkNotNullExpressionValue(createInsecureHostnameVerifier, "createInsecureHostnameVerifier(...)");
        builder.hostnameVerifier(createInsecureHostnameVerifier);
        return builder.build();
    }

    private final OkHttpClient newClient2() {
        OkHttpClient.Builder builder = new OkHttpClient.Builder();
        builder.connectTimeout(30L, TimeUnit.SECONDS);
        builder.readTimeout(10L, TimeUnit.SECONDS);
        builder.writeTimeout(10L, TimeUnit.SECONDS);
        HostnameVerifier createInsecureHostnameVerifier = HttpSSLUtils.createInsecureHostnameVerifier();
        Intrinsics.checkNotNullExpressionValue(createInsecureHostnameVerifier, "createInsecureHostnameVerifier(...)");
        builder.hostnameVerifier(createInsecureHostnameVerifier);
        return builder.build();
    }

    /* JADX INFO: Access modifiers changed from: private */
    /* compiled from: BaseRetrofit.kt */
    @Metadata(d1 = {"\u0000\u0018\n\u0002\u0018\u0002\n\u0002\u0018\u0002\n\u0002\b\u0003\n\u0002\u0018\u0002\n\u0000\n\u0002\u0018\u0002\n\u0000\b\u0002\u0018\u00002\u00020\u0001B\u0007¢\u0006\u0004\b\u0002\u0010\u0003J\u0010\u0010\u0004\u001a\u00020\u00052\u0006\u0010\u0006\u001a\u00020\u0007H\u0016¨\u0006\b"}, d2 = {"Lcom/sibyl/app/http/BaseRetrofit$TokenInterceptor;", "Lokhttp3/Interceptor;", "<init>", "()V", "intercept", "Lokhttp3/Response;", "chain", "Lokhttp3/Interceptor$Chain;", "app_release"}, k = 1, mv = {2, 2, 0}, xi = 48)
    static final class TokenInterceptor implements Interceptor {
        @Override // okhttp3.Interceptor
        public Response intercept(Interceptor.Chain chain) {
            Intrinsics.checkNotNullParameter(chain, "chain");
            Request.Builder addHeader = chain.request().newBuilder().addHeader("Content-Type", "application/json; charset=utf-8").addHeader("User-Agent", "Android-XT-Water-Phone");
            String language = Locale.getDefault().getLanguage();
            Intrinsics.checkNotNullExpressionValue(language, "getLanguage(...)");
            Request.Builder addHeader2 = addHeader.addHeader("lang", language);
            String country = Locale.getDefault().getCountry();
            Intrinsics.checkNotNullExpressionValue(country, "getCountry(...)");
            Request.Builder addHeader3 = addHeader2.addHeader("country", country);
            String language2 = Locale.getDefault().getLanguage();
            Intrinsics.checkNotNullExpressionValue(language2, "getLanguage(...)");
            Request.Builder addHeader4 = addHeader3.addHeader("language", language2).addHeader("appVerson", "1.26").addHeader("loginSys", "Android," + Build.VERSION.SDK_INT);
            String DEVICE = Build.DEVICE;
            Intrinsics.checkNotNullExpressionValue(DEVICE, "DEVICE");
            Request.Builder addHeader5 = addHeader4.addHeader("mobile", DEVICE).addHeader("userName", HttpUrl.FRAGMENT_ENCODE_SET).addHeader("loginIp", HttpUrl.FRAGMENT_ENCODE_SET).addHeader("qId", "1");
            String token = SPExtKt.getToken();
            if (!TextUtils.isEmpty(token)) {
                addHeader5.addHeader("Authorization", "Bearer " + token);
            }
            Request build = addHeader5.build();
            BaseRetrofit.INSTANCE.logRequest(build);
            return BaseRetrofit.INSTANCE.logResponse(chain.proceed(build), null);
        }
    }

    /* JADX INFO: Access modifiers changed from: private */
    public final void logRequest(Request request) {
        MediaType contentType;
        try {
            NetworkResponseEntity networkResponseEntity = new NetworkResponseEntity();
            networkResponseEntity.setUrl(request.url().getUrl());
            networkResponseEntity.setMethod(request.method());
            Headers headers = request.headers();
            if (headers.size() > 0) {
                networkResponseEntity.setHeaders(headers.toString());
            }
            RequestBody body = request.body();
            if (body != null && (contentType = body.contentType()) != null) {
                if (isText(contentType)) {
                    networkResponseEntity.setSend(bodyToString(request));
                } else {
                    networkResponseEntity.setSend("非文本数据，无法打印");
                }
            }
            networkResponseEntity.printRequest();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private final boolean isText(MediaType mediaType) {
        return Intrinsics.areEqual(mediaType.type(), "text") || Intrinsics.areEqual(mediaType.subtype(), "json") || Intrinsics.areEqual(mediaType.subtype(), "xml") || Intrinsics.areEqual(mediaType.subtype(), "html") || Intrinsics.areEqual(mediaType.subtype(), "webviewhtml") || Intrinsics.areEqual(mediaType.subtype(), "x-www-form-urlencoded");
    }

    private final String bodyToString(Request request) {
        try {
            Request build = request.newBuilder().build();
            Buffer buffer = new Buffer();
            RequestBody body = build.body();
            Intrinsics.checkNotNull(body);
            body.writeTo(buffer);
            return buffer.readUtf8();
        } catch (IOException unused) {
            return "something error when show requestBody.";
        }
    }

    /* JADX INFO: Access modifiers changed from: private */
    public final Response logResponse(Response response, CrashCallBack crashCallBack) {
        NetworkResponseEntity networkResponseEntity = new NetworkResponseEntity();
        networkResponseEntity.setSendTime(response.sentRequestAtMillis());
        networkResponseEntity.setReceiveTime(response.receivedResponseAtMillis());
        networkResponseEntity.setCode(response.code());
        networkResponseEntity.setMessage(response.message());
        networkResponseEntity.setRedirect(response.isRedirect());
        networkResponseEntity.setProtocol(response.protocol().toString());
        networkResponseEntity.setSuccessful(response.isSuccessful());
        networkResponseEntity.setUrl(response.request().url().getUrl());
        networkResponseEntity.setHttps(response.request().isHttps());
        networkResponseEntity.setMethod(response.request().method());
        Headers headers = response.headers();
        String str = HttpUrl.FRAGMENT_ENCODE_SET;
        if (headers != null) {
            networkResponseEntity.setHeaders(response.headers().toString());
        } else {
            networkResponseEntity.setHeaders(HttpUrl.FRAGMENT_ENCODE_SET);
        }
        if (response.request().body() != null) {
            try {
                Buffer buffer = new Buffer();
                RequestBody body = response.request().body();
                Intrinsics.checkNotNull(body);
                body.writeTo(buffer);
                Charset.forName("UTF-8");
                RequestBody body2 = response.request().body();
                Intrinsics.checkNotNull(body2);
                MediaType contentType = body2.contentType();
                if (contentType != null) {
                    if (isText(contentType)) {
                        Charset charset = contentType.charset(Charset.forName("UTF-8"));
                        Intrinsics.checkNotNull(charset);
                        networkResponseEntity.setSend(buffer.readString(charset));
                    } else {
                        networkResponseEntity.setSend("非文本数据，无法打印");
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
        if (response.body() != null) {
            ResponseBody body3 = response.body();
            Intrinsics.checkNotNull(body3);
            String string = body3.string();
            if (string != null) {
                str = string;
            }
            networkResponseEntity.setContent(str);
        }
        networkResponseEntity.printResponse(crashCallBack);
        Response.Builder newBuilder = response.newBuilder();
        ResponseBody.Companion companion = ResponseBody.INSTANCE;
        String content = networkResponseEntity.getContent();
        Intrinsics.checkNotNullExpressionValue(content, "getContent(...)");
        ResponseBody body4 = response.body();
        Intrinsics.checkNotNull(body4);
        return newBuilder.body(companion.create(content, body4.contentType())).build();
    }
}
