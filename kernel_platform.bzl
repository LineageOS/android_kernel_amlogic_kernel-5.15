load("//build/kernel/kleaf:kernel.bzl", "kernel_abi", "kernel_build", "kernel_images", "kernel_modules_install", "merged_kernel_uapi_headers")
load("//build/bazel_common_rules/dist:dist.bzl", "copy_to_dist_dir")
load(":modules.bzl", "get_gki_modules_list")

_IMAGE_OUTS = [
    "Image",
    "Image.lz4",
    "System.map",
    "modules.builtin",
    "modules.builtin.modinfo",
    "vmlinux",
    "vmlinux.symvers",
]

_DTC = "//prebuilts/kernel-build-tools:linux-x86/bin/dtc"
_DTBTOOL = "//tools/dtbtool:dtbToolAmlogic"

_DTB_GZIP_THRESHOLD = 200 * 1024
_GZIP_CMD = """
if [ "$$(stat -c%s $@)" -gt {threshold} ]; then
    gzip -c $@ > $@.gz && mv $@.gz $@
fi
""".format(threshold = _DTB_GZIP_THRESHOLD)

def _dtb_image(name, dtb_srcs):
    if len(dtb_srcs) == 1:
        native.genrule(
            name = name,
            srcs = dtb_srcs,
            outs = ["dtb.img"],
            cmd = "cp -L $< $@\n" + _GZIP_CMD,
        )
        return

    native.genrule(
        name = name,
        srcs = dtb_srcs,
        outs = ["dtb.img"],
        tools = [_DTBTOOL, _DTC],
        # dtbTool only takes a directory, which it scans non-recursively for *.dtb,
        # so gather the DTBs into a staging dir.
        cmd = """
            staging=$(@D)/%s/staging
            rm -rf $$staging && mkdir -p $$staging
            cp -L $(SRCS) $$staging/
            $(location %s) -o $@ -p "$$(dirname $(location %s))/" $$staging
            rm -rf $$staging
        """ % (name, _DTBTOOL, _DTC) + _GZIP_CMD,
    )

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
    dtb_img_srcs = [":{}/{}".format(name, o) for o in dtb_outs if o.endswith(".dtb")]

    kernel_build(
        name = name,
        srcs = [
            "//vendor/amlogic/kernel:common_kernel_sources",
            "//vendor/amlogic/common_drivers:common_drivers_srcs",
        ],
        outs = _IMAGE_OUTS + dtb_outs,
        build_config = build_config,
        kconfig_ext = "//vendor/amlogic/common_drivers:Kconfig.ext",
        dtstree = "//vendor/amlogic/common_drivers:common_drivers_dtstree",
        collect_unstripped_modules = True,
        strip_modules = True,
        module_outs = module_outs,
        module_implicit_outs = get_gki_modules_list("arm64"),
        make_goals = ["Image", "Image.lz4", "modules"] +
                     ["amlogic/" + o for o in dtb_outs] + (make_goals or []),
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

    _dtb_image(
        name = name + "_dtb_image",
        dtb_srcs = dtb_img_srcs,
    )

    copy_to_dist_dir(
        name = name + "_dist",
        data = [
            ":" + name,
            ":" + name + "_images",
            ":" + name + "_dtb_image",
            ":" + name + "_modules_install",
            ":" + name + "_merged_kernel_uapi_headers",
        ],
        dist_dir = "out/{}/dist".format(name),
        flat = True,
        log = "info",
    )
