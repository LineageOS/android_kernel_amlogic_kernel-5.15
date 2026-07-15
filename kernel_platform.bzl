load("//build/kernel/kleaf:kernel.bzl", "kernel_abi", "kernel_build", "kernel_images", "kernel_modules_install", "merged_kernel_uapi_headers")
load("//build/bazel_common_rules/dist:dist.bzl", "copy_to_dist_dir")

def amlogic_kernel_platform(
        name,
        dtb_outs,
        module_outs,
        kernel_modules = None,
        build_config = None,
        kmi_symbol_list = None,
        dtbo_srcs = None,
        make_goals = None):
    kernel_modules = kernel_modules or []
    build_config = build_config or "//vendor/amlogic/kernel:build.config.{}.bazel".format(name)
    dtbo_outs = [o for o in dtb_outs if o.endswith(".dtbo")]
    dtbo_srcs = dtbo_srcs or [":{}/{}".format(name, o) for o in dtbo_outs]

    kernel_build(
        name = name,
        srcs = [
            "//vendor/amlogic/kernel:common_kernel_sources",
            "//vendor/amlogic/common_drivers:common_drivers_srcs",
        ],
        outs = dtb_outs,
        base_kernel = "//vendor/amlogic/kernel:kernel_aarch64_download_or_build",
        build_config = build_config,
        kconfig_ext = "//vendor/amlogic/common_drivers:Kconfig.ext",
        kmi_symbol_list = kmi_symbol_list,
        dtstree = "//vendor/amlogic/common_drivers:common_drivers_dtstree",
        collect_unstripped_modules = True,
        strip_modules = True,
        module_outs = module_outs,
        make_goals = ["modules"] + ["amlogic/" + o for o in dtb_outs] + (make_goals or []),
    )

    kernel_abi(
        name = name + "_abi",
        kernel_build = ":" + name,
        define_abi_targets = True,
        kmi_symbol_list_add_only = True,
        module_grouping = False,
    )

    kernel_modules_install(
        name = name + "_modules_install",
        kernel_build = ":" + name,
        kernel_modules = kernel_modules,
    )

    merged_kernel_uapi_headers(
        name = name + "_merged_kernel_uapi_headers",
        kernel_build = ":" + name,
    )

    kernel_images(
        name = name + "_images",
        build_dtbo = True,
        dtbo_srcs = dtbo_srcs,
        build_initramfs = True,
        kernel_build = ":" + name,
        kernel_modules_install = ":" + name + "_modules_install",
    )

    copy_to_dist_dir(
        name = name + "_dist",
        data = [
            ":" + name,
            ":" + name + "_images",
            ":" + name + "_modules_install",
            ":" + name + "_merged_kernel_uapi_headers",
            "//vendor/amlogic/kernel:kernel_aarch64_download_or_build",
            "//vendor/amlogic/kernel:kernel_aarch64_additional_artifacts_download_or_build",
            "//vendor/amlogic/kernel:kernel_aarch64_modules",
        ],
        dist_dir = "out/{}/dist".format(name),
        flat = True,
        log = "info",
    )
