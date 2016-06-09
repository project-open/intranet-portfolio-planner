<if @error_json@ ne "">
@error_json;noquote@
</if><else>
{'text':'.','children': [
@json;noquote@
}
</else>
